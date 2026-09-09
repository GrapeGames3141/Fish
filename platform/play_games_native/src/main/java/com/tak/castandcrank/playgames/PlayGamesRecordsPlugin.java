package com.tak.castandcrank.playgames;

import android.app.Activity;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import androidx.annotation.NonNull;
import com.google.android.gms.games.AnnotatedData;
import com.google.android.gms.games.AuthenticationResult;
import com.google.android.gms.games.GamesSignInClient;
import com.google.android.gms.games.LeaderboardsClient;
import com.google.android.gms.games.PlayGames;
import com.google.android.gms.games.PlayGamesSdk;
import com.google.android.gms.games.leaderboard.LeaderboardScore;
import com.google.android.gms.games.leaderboard.LeaderboardScoreBuffer;
import com.google.android.gms.games.leaderboard.LeaderboardVariant;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONException;
import org.json.JSONObject;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/** Optional JSON-only Play Games v2 boundary. The app maintains no offline score queue. */
public final class PlayGamesRecordsPlugin extends GodotPlugin {
    private final Map<String, BoardPending> pendingBoards = new HashMap<>();

    private static final class ScoreCopy {
        long millimetres;
        long rank;
        String playerName = "";
    }

    private static final class BoardPending {
        final String fishId;
        final String period;
        final long requestId;
        final long accountGeneration;
        ScoreCopy top;
        ScoreCopy player;
        boolean topCached;
        boolean playerCached;
        boolean sent;
        BoardPending(String fishId, String period, long requestId, long accountGeneration) {
            this.fishId = fishId; this.period = period;
            this.requestId = requestId; this.accountGeneration = accountGeneration;
        }
    }

    public PlayGamesRecordsPlugin(Godot godot) { super(godot); }

    @NonNull @Override public String getPluginName() { return "PlayGamesRecords"; }

    @NonNull @Override public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("play_games_event", String.class));
        return signals;
    }

    private void onUi(final long requestId, final long accountGeneration, final String kind, Runnable task) {
        Activity activity = getActivity();
        if (activity == null || activity.isFinishing() || activity.isDestroyed()) { emitError(kind, requestId, accountGeneration, "activity_unavailable"); return; }
        activity.runOnUiThread(() -> {
            Activity current = getActivity();
            if (current == null || current.isFinishing() || current.isDestroyed()) { emitError(kind, requestId, accountGeneration, "activity_unavailable"); return; }
            try { task.run(); } catch (Exception error) { emitError(kind, requestId, accountGeneration, errorName(error)); }
        });
    }

    private Activity activeActivity(final String operation, final long requestId, final long accountGeneration) {
        Activity activity = getActivity();
        if (activity == null || activity.isFinishing() || activity.isDestroyed()) {
            emitError(operation, requestId, accountGeneration, "activity_unavailable");
            return null;
        }
        return activity;
    }

    private boolean hasValidatedNetwork(Activity activity) {
        ConnectivityManager manager = (ConnectivityManager) activity.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (manager == null) return false;
        Network network = manager.getActiveNetwork();
        NetworkCapabilities capabilities = network == null ? null : manager.getNetworkCapabilities(network);
        return capabilities != null && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED);
    }

    private JSONObject event(String kind, long requestId, long accountGeneration) throws JSONException {
        JSONObject object = new JSONObject();
        object.put("kind", kind); object.put("request_id", requestId); object.put("account_generation", accountGeneration);
        return object;
    }
    private void emit(JSONObject object) { emitSignal("play_games_event", object.toString()); }
    private void emitError(String operation, long requestId, long accountGeneration, String reason) {
        try {
            JSONObject object = event("error", requestId, accountGeneration);
            object.put("operation", operation); object.put("reason", reason == null ? "unknown" : reason); emit(object);
        } catch (JSONException ignored) { }
    }
    private static String errorName(Exception error) { return error == null ? "unknown" : error.getClass().getSimpleName(); }

    @UsedByGodot public void initialize(final long requestId, final long accountGeneration) {
        onUi(requestId, accountGeneration, "initialize", () -> {
            try { PlayGamesSdk.initialize(getActivity().getApplicationContext()); checkAuthentication(requestId, accountGeneration, "initialize"); }
            catch (Exception error) { emitError("initialize", requestId, accountGeneration, errorName(error)); }
        });
    }
    @UsedByGodot public void isAuthenticated(final long requestId, final long accountGeneration) {
        onUi(requestId, accountGeneration, "auth_check", () -> checkAuthentication(requestId, accountGeneration, "auth_check"));
    }
    @UsedByGodot public void signIn(final long requestId, final long accountGeneration) {
        onUi(requestId, accountGeneration, "sign_in", () -> PlayGames.getGamesSignInClient(getActivity()).signIn()
                .addOnSuccessListener(result -> emitAuthentication(result, requestId, accountGeneration, "sign_in"))
                .addOnFailureListener(error -> emitError("sign_in", requestId, accountGeneration, errorName(error))));
    }
    private void checkAuthentication(final long requestId, final long accountGeneration, final String operation) {
        Activity activity = activeActivity(operation, requestId, accountGeneration); if (activity == null) return;
        try {
            GamesSignInClient client = PlayGames.getGamesSignInClient(activity);
            client.isAuthenticated().addOnSuccessListener(result -> emitAuthentication(result, requestId, accountGeneration, operation))
                    .addOnFailureListener(error -> emitError(operation, requestId, accountGeneration, errorName(error)));
        } catch (Exception error) { emitError(operation, requestId, accountGeneration, errorName(error)); }
    }
    private void emitAuthentication(AuthenticationResult result, long requestId, long accountGeneration, String operation) {
        if (result == null || !result.isAuthenticated()) {
            try { JSONObject object = event("auth", requestId, accountGeneration); object.put("operation", operation); object.put("state", "unauthenticated"); object.put("account_id", ""); emit(object); } catch (JSONException ignored) { }
            return;
        }
        Activity activity = activeActivity("account", requestId, accountGeneration); if (activity == null) return;
        try {
            PlayGames.getPlayersClient(activity).getCurrentPlayerId().addOnSuccessListener(playerId -> {
                if (activeActivity("account", requestId, accountGeneration) == null) return;
                try { JSONObject object = event("auth", requestId, accountGeneration); object.put("operation", operation); object.put("state", "authenticated"); object.put("account_id", playerId == null ? "" : playerId); emit(object); } catch (JSONException ignored) { }
            }).addOnFailureListener(error -> emitError("account", requestId, accountGeneration, errorName(error)));
        } catch (Exception error) { emitError("account", requestId, accountGeneration, errorName(error)); }
    }

    @UsedByGodot public void requestLeaderboard(final String fishId, final String leaderboardId, final boolean weekly, final long requestId, final long accountGeneration, final String expectedAccountId) {
        onUi(requestId, accountGeneration, "leaderboard", () -> {
            if (leaderboardId == null || leaderboardId.trim().isEmpty()) { emitError("leaderboard", requestId, accountGeneration, "unconfigured"); return; }
            validateAccount(expectedAccountId, requestId, accountGeneration, "leaderboard", () -> {
                final String key = requestId + ":" + accountGeneration + ":" + fishId;
                final BoardPending pending = new BoardPending(fishId, weekly ? "WEEKLY" : "ALL TIME", requestId, accountGeneration);
                pendingBoards.put(key, pending);
                final int span = weekly ? LeaderboardVariant.TIME_SPAN_WEEKLY : LeaderboardVariant.TIME_SPAN_ALL_TIME;
                Activity activity = activeActivity("leaderboard", requestId, accountGeneration); if (activity == null) { failBoard(key, "activity_unavailable"); return; }
                try {
                    final LeaderboardsClient client = PlayGames.getLeaderboardsClient(activity);
                    client.loadTopScores(leaderboardId, span, LeaderboardVariant.COLLECTION_PUBLIC, 1, true)
                            .addOnSuccessListener(data -> completeTop(key, data, expectedAccountId)).addOnFailureListener(error -> failBoard(key, errorName(error)));
                    client.loadCurrentPlayerLeaderboardScore(leaderboardId, span, LeaderboardVariant.COLLECTION_PUBLIC)
                            .addOnSuccessListener(data -> completePlayer(key, data, expectedAccountId)).addOnFailureListener(error -> failBoard(key, errorName(error)));
                } catch (Exception error) { failBoard(key, errorName(error)); }
            });
        });
    }
    private void validateAccount(final String expectedAccountId, final long requestId, final long accountGeneration, final String operation, Runnable success) {
        if (expectedAccountId == null || expectedAccountId.isEmpty()) { emitError(operation, requestId, accountGeneration, "missing_account"); return; }
        Activity activity = activeActivity(operation, requestId, accountGeneration); if (activity == null) return;
        try {
            PlayGames.getPlayersClient(activity).getCurrentPlayerId().addOnSuccessListener(playerId -> {
                if (activeActivity(operation, requestId, accountGeneration) == null) return;
                if (!expectedAccountId.equals(playerId)) { emitError(operation, requestId, accountGeneration, "account_changed"); return; }
                try { success.run(); } catch (Exception error) { emitError(operation, requestId, accountGeneration, errorName(error)); }
            }).addOnFailureListener(error -> emitError(operation, requestId, accountGeneration, errorName(error)));
        } catch (Exception error) { emitError(operation, requestId, accountGeneration, errorName(error)); }
    }
    private ScoreCopy copyScore(LeaderboardScore score) {
        ScoreCopy copy = new ScoreCopy();
        if (score != null) { copy.millimetres = score.getRawScore(); copy.rank = score.getRank(); String name = score.getScoreHolderDisplayName(); copy.playerName = name == null ? "" : name; }
        return copy;
    }
    private void completeTop(String key, AnnotatedData<LeaderboardsClient.LeaderboardScores> annotated, String accountId) {
        LeaderboardsClient.LeaderboardScores scores = annotated == null ? null : annotated.get();
        try {
            BoardPending pending = pendingBoards.get(key); if (pending == null || pending.sent) return;
            LeaderboardScoreBuffer buffer = scores == null ? null : scores.getScores(); pending.top = copyScore(buffer != null && buffer.getCount() > 0 ? buffer.get(0) : null);
            pending.topCached = annotated != null && annotated.isStale();
            emitBoardIfComplete(key, pending, accountId);
        }
        finally { if (scores != null) scores.release(); }
    }
    private void completePlayer(String key, AnnotatedData<LeaderboardScore> annotated, String accountId) {
        BoardPending pending = pendingBoards.get(key); if (pending == null || pending.sent) return;
        pending.player = copyScore(annotated == null ? null : annotated.get()); pending.playerCached = annotated != null && annotated.isStale(); emitBoardIfComplete(key, pending, accountId);
    }
    private void emitBoardIfComplete(String key, BoardPending pending, String accountId) {
        if (pending.top == null || pending.player == null || pending.sent) return;
        pending.sent = true; pendingBoards.remove(key);
        try {
            JSONObject object = event("board", pending.requestId, pending.accountGeneration);
            object.put("fish_id", pending.fishId); object.put("period", pending.period);
            object.put("account_id", accountId); object.put("cached", pending.topCached || pending.playerCached);
            object.put("top_score_mm", pending.top.millimetres); object.put("top_rank", pending.top.rank); object.put("top_name", pending.top.playerName);
            object.put("player_score_mm", pending.player.millimetres); object.put("player_rank", pending.player.rank); object.put("player_name", pending.player.playerName);
            object.put("empty", pending.top.millimetres <= 0 && pending.player.millimetres <= 0); emit(object);
        } catch (JSONException ignored) { }
    }
    private void failBoard(String key, String reason) {
        BoardPending pending = pendingBoards.remove(key); if (pending != null && !pending.sent) emitError("leaderboard", pending.requestId, pending.accountGeneration, reason);
    }

    @UsedByGodot public void submitScore(final String fishId, final String leaderboardId, final long millimetres, final long requestId, final long accountGeneration, final String expectedAccountId) {
        onUi(requestId, accountGeneration, "submit", () -> {
            if (leaderboardId == null || leaderboardId.trim().isEmpty() || millimetres <= 0) { emitError("submit", requestId, accountGeneration, "invalid_score"); return; }
            Activity activity = activeActivity("submit", requestId, accountGeneration); if (activity == null) return;
            if (!hasValidatedNetwork(activity)) { emitError("submit", requestId, accountGeneration, "offline"); return; }
            validateAccount(expectedAccountId, requestId, accountGeneration, "submit", () -> {
                Activity checkedActivity = activeActivity("submit", requestId, accountGeneration); if (checkedActivity == null) return;
                if (!hasValidatedNetwork(checkedActivity)) { emitError("submit", requestId, accountGeneration, "offline"); return; }
                try {
                    PlayGames.getLeaderboardsClient(checkedActivity).submitScoreImmediate(leaderboardId, millimetres)
                            .addOnSuccessListener(data -> { if (activeActivity("submit", requestId, accountGeneration) == null) return; try { JSONObject object = event("submit", requestId, accountGeneration); object.put("fish_id", fishId); object.put("score_mm", millimetres); object.put("account_id", expectedAccountId); object.put("state", "submitted"); emit(object); } catch (JSONException ignored) { } })
                            .addOnFailureListener(error -> emitError("submit", requestId, accountGeneration, errorName(error)));
                } catch (Exception error) { emitError("submit", requestId, accountGeneration, errorName(error)); }
            });
        });
    }
}

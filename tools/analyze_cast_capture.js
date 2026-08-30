#!/usr/bin/env node
/*
 * Deterministic offline replay for an explicitly user-authorized ten-cast
 * capture. It intentionally never writes sensor vectors to stdout: the JSON
 * input remains the sole raw-trace artifact, while this tool writes only
 * replay outcomes and aggregate descriptive statistics.
 *
 * Usage:
 *   node tools/analyze_cast_capture.js [input-json] [output-json] [output-md]
 */

"use strict";

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const ROOT = process.cwd();
const DEFAULT_INPUT = path.join(ROOT, "reports", "device", "pixel9pro-cast-capture-v21-2026-08-30.json");
const DEFAULT_JSON = path.join(ROOT, "reports", "device", "pixel9pro-cast-capture-v21-2026-08-30-analysis.json");
const DEFAULT_MARKDOWN = path.join(ROOT, "reports", "device", "pixel9pro-cast-capture-v21-2026-08-30-analysis.md");
const V21_CAPTURE_FILENAME = "pixel9pro-cast-capture-v21-2026-08-30.json";
const V21_CAPTURE_SHA256 = "DA61E2A901E70266786D903DEC763132124B6BBB8B89A6B3B6A3DD9E69AD8F70";

// MotionService v21 runtime constants. Keep this section in lockstep with
// src/services/motion_service.gd; the report records it explicitly so a later
// tuning change cannot silently reinterpret this capture.
const CONFIG = Object.freeze({
  backNoiseFactor: 1.9,
  backPeakFactor: 0.58,
  forwardNoiseFactor: 1.8,
  forwardPeakFactor: 0.42,
  runtimeSweepEntryFactor: 0.35,
  runtimeSweepMinSamples: 3,
  runtimeSweepMaxDeltaSeconds: 0.05,
  runtimeFullReversalSeconds: 0.22,
  runtimeMaxReversalSeconds: 0.65,
  runtimeXPolarityAlignment: 0.18,
  gyroFactor: 0.16,
  gyroMin: 0.10,
  gyroMax: 0.60,
  qualityFloor: 0.05,
});

const COCK_FACTORS = [0.045, 0.0475, 0.050, 0.0525, 0.055];
const SNAP_FACTORS = [0.055, 0.0625, 0.070];
// Candidate asymmetric recognizer grid: physical-X is only substituted for
// the right-handed cock. The forward snap deliberately stays on the learned
// 3D profile axis and its current v21 shape factor (.055).
const PHYSICAL_COCK_THRESHOLD_MULTIPLIERS = [1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0];
const PHYSICAL_COCK_IMPULSE_FACTORS = [0.045, 0.055, 0.065, 0.075, 0.090];
// This grid fixes the selected physical-cock candidate (6×/.045) and changes
// only the snap's final amplitude gate. Its learned 3D axis, .18 physical
// polarity, .60 gyro, three-sample shape, .055 impulse, and .65s reversal
// remain deliberately fixed.
const SNAP_FINAL_THRESHOLD_MULTIPLIERS = [1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32];

function die(message) {
  process.stderr.write(`ERROR: ${message}\n`);
  process.exitCode = 1;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }
function dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
function subtract(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
function length(v) { return Math.hypot(v[0], v[1], v[2]); }
function normalize(v) {
  const len = length(v);
  return len > 0 ? [v[0] / len, v[1] / len, v[2] / len] : [0, 0, 0];
}
function magnitude(v) { return length(v); }
function round(value, digits = 4) {
  const p = 10 ** digits;
  return Math.round(value * p) / p;
}
function quantile(values, q) {
  const sorted = values.filter(Number.isFinite).slice().sort((a, b) => a - b);
  if (!sorted.length) return null;
  const at = (sorted.length - 1) * q;
  const low = Math.floor(at);
  const high = Math.ceil(at);
  return sorted[low] + (sorted[high] - sorted[low]) * (at - low);
}
function descriptive(values) {
  const clean = values.filter(Number.isFinite);
  return {
    count: clean.length,
    min: round(Math.min(...clean)),
    p10: round(quantile(clean, 0.10)),
    p25: round(quantile(clean, 0.25)),
    p50: round(quantile(clean, 0.50)),
    p75: round(quantile(clean, 0.75)),
    p90: round(quantile(clean, 0.90)),
    max: round(Math.max(...clean)),
  };
}
function median(values) { return quantile(values, 0.5); }
function labelFactor(value) { return value.toFixed(4).replace(/0+$/, "").replace(/\.$/, ""); }

function runtimeGates(metadata) {
  const profile = metadata.motion_profile;
  const sensitivity = Math.max(Number(metadata.sensitivity) || 1, 0.5);
  const cock = Math.max(profile.noise_floor * CONFIG.backNoiseFactor, profile.back_peak * CONFIG.backPeakFactor) / sensitivity;
  const snap = Math.max(profile.noise_floor * CONFIG.forwardNoiseFactor, profile.forward_peak * CONFIG.forwardPeakFactor) / sensitivity;
  const gyro = clamp(profile.gyro_peak * CONFIG.gyroFactor / sensitivity, CONFIG.gyroMin, CONFIG.gyroMax);
  return {
    cock_threshold: cock,
    snap_threshold: snap,
    cock_entry: Math.max(0.15, cock * CONFIG.runtimeSweepEntryFactor),
    snap_entry: Math.max(0.15, snap * CONFIG.runtimeSweepEntryFactor),
    gyro_threshold: gyro,
    direction_tolerance: profile.direction_tolerance,
    polarity_tolerance: CONFIG.runtimeXPolarityAlignment,
  };
}

function failureReason(linearMagnitude, gyroMagnitude, axisMatch, polarityMatch, threshold, axisTolerance, polarityTolerance, gyroTolerance) {
  if (linearMagnitude < threshold) return "linear";
  if (polarityMatch < polarityTolerance) return "polarity";
  if (axisMatch < axisTolerance) return "axis";
  if (gyroMagnitude < gyroTolerance) return "gyro";
  return null;
}

function createStage() {
  return { samples: 0, impulse: 0, attemptLatched: false, failureLatched: false };
}

function resetStage(stage) {
  stage.samples = 0;
  stage.impulse = 0;
  stage.attemptLatched = false;
  stage.failureLatched = false;
}

function advanceSweep(stage, projection, threshold, deltaSeconds, factor) {
  const entry = Math.max(0.15, threshold * CONFIG.runtimeSweepEntryFactor);
  if (projection <= entry) {
    resetStage(stage);
    return { ready: false, entry, reset: true };
  }
  stage.samples += 1;
  stage.impulse += Math.max(projection - entry, 0) * Math.min(Math.max(deltaSeconds, 0), CONFIG.runtimeSweepMaxDeltaSeconds);
  return {
    ready: stage.samples >= CONFIG.runtimeSweepMinSamples && stage.impulse >= threshold * factor,
    entry,
    reset: false,
  };
}

function quality(forwardProjection, forwardThreshold, forwardPeak, elapsed) {
  const peak = Math.max(forwardPeak, forwardThreshold + 0.01);
  const strength = clamp(0.35 + ((forwardProjection - forwardThreshold) / Math.max(peak * 0.80, 0.1)) * 0.65, 0.35, 1.0);
  let timing = 1;
  if (elapsed > CONFIG.runtimeFullReversalSeconds) {
    const normal = clamp((elapsed - CONFIG.runtimeFullReversalSeconds) / (CONFIG.runtimeMaxReversalSeconds - CONFIG.runtimeFullReversalSeconds), 0, 1);
    timing = 1 + (0.12 - 1) * normal;
  }
  return clamp(strength * timing, CONFIG.qualityFloor, 1);
}

function firstFailure(stageName, state, sample, metrics, thresholds, atMs, failures) {
  if (state.failureLatched) return;
  const reason = failureReason(metrics.linearMagnitude, metrics.gyroMagnitude, metrics.axisMatch, metrics.polarityMatch, thresholds.final, thresholds.axis, thresholds.polarity, thresholds.gyro);
  if (!reason) return;
  state.failureLatched = true;
  failures.push({ stage: stageName, reason, at_ms: atMs, sample: sample.index + 1 });
}

function replayWindow(cast, metadata, gates, cockFactor, snapFactor, firstDelta) {
  const profile = metadata.motion_profile;
  const leftHanded = metadata.handedness === "left";
  const forwardAxis = leftHanded ? [1, 0, 0] : [-1, 0, 0];
  const backAxis = forwardAxis.map(v => -v);
  const axis = normalize(profile.forward_axis);
  const cockState = createStage();
  const snapState = createStage();
  const events = { arms: [], casts: [], failures: [], premature: [] };
  let phase = "cock";
  let cooldown = 0;
  let reversalElapsed = 0;
  let priorT = null;
  let armSample = null;
  let activeArm = null;

  for (let index = 0; index < cast.samples.length; index += 1) {
    const raw = cast.samples[index];
    const tMs = Number(raw.t_ms);
    const delta = priorT === null ? firstDelta : Math.max(0, (tMs - priorT) / 1000);
    priorT = tMs;
    cooldown = Math.max(0, cooldown - delta);
    if (cooldown > 0) continue;
    // CastCaptureService derives linear acceleration before it independently
    // clamps each persisted vector component. Reuse its saved `linear` field:
    // subtracting the two persisted/clamped source vectors would distort a
    // saturated high-motion sample and would not replay MotionService input.
    const linear = Array.isArray(raw.linear) && raw.linear.length === 3 ? raw.linear : subtract(raw.accelerometer, raw.gravity);
    const linearLength = magnitude(linear);
    const gyroLength = magnitude(raw.gyro);
    const normalized = normalize(linear);
    const elapsedMs = tMs - Number(cast.samples[0].t_ms);

    if (phase === "cock") {
      const projection = -dot(linear, axis);
      const metrics = {
        linearMagnitude: linearLength,
        gyroMagnitude: gyroLength,
        axisMatch: linearLength > 0 ? -dot(normalized, axis) : -1,
        polarityMatch: linearLength > 0 ? dot(normalized, backAxis) : -1,
      };
      const sweep = advanceSweep(cockState, projection, gates.cock_threshold, delta, cockFactor);
      if (sweep.ready && projection >= gates.cock_threshold) {
        if (!cockState.attemptLatched) cockState.attemptLatched = true;
        const accepted = metrics.axisMatch >= gates.direction_tolerance && metrics.polarityMatch >= gates.polarity_tolerance && gyroLength >= gates.gyro_threshold;
        if (accepted) {
          const event = {
            at_ms: elapsedMs,
            sample: index + 1,
            projection: round(projection),
            impulse: round(cockState.impulse),
            samples: cockState.samples,
            axis_match: round(metrics.axisMatch),
            polarity_match: round(metrics.polarityMatch),
            gyro: round(gyroLength),
          };
          events.arms.push(event);
          activeArm = event;
          armSample = index;
          reversalElapsed = 0;
          phase = "snap";
        } else {
          firstFailure("cock", cockState, { index }, metrics, { final: gates.cock_threshold, axis: gates.direction_tolerance, polarity: gates.polarity_tolerance, gyro: gates.gyro_threshold }, elapsedMs, events.failures);
        }
      }
      continue;
    }

    reversalElapsed += delta;
    if (reversalElapsed > CONFIG.runtimeMaxReversalSeconds) {
      events.failures.push({ stage: "snap", reason: "timeout", at_ms: elapsedMs, sample: index + 1, arm_sample: armSample + 1 });
      phase = "cock";
      resetStage(cockState);
      resetStage(snapState);
      activeArm = null;
      continue;
    }
    const projection = dot(linear, axis);
    const metrics = {
      linearMagnitude: linearLength,
      gyroMagnitude: gyroLength,
      axisMatch: linearLength > 0 ? dot(normalized, axis) : -1,
      polarityMatch: linearLength > 0 ? dot(normalized, forwardAxis) : -1,
    };
    const sweep = advanceSweep(snapState, projection, gates.snap_threshold, delta, snapFactor);
    if (sweep.ready && projection >= gates.snap_threshold) {
      if (!snapState.attemptLatched) snapState.attemptLatched = true;
      const accepted = metrics.axisMatch >= gates.direction_tolerance && metrics.polarityMatch >= gates.polarity_tolerance && gyroLength >= gates.gyro_threshold;
      if (accepted) {
        const event = {
          at_ms: elapsedMs,
          sample: index + 1,
          projection: round(projection),
          impulse: round(snapState.impulse),
          samples: snapState.samples,
          axis_match: round(metrics.axisMatch),
          polarity_match: round(metrics.polarityMatch),
          gyro: round(gyroLength),
          reversal_ms: round(reversalElapsed * 1000, 1),
          quality: round(quality(projection, gates.snap_threshold, profile.forward_peak, reversalElapsed)),
          arm_at_ms: activeArm ? activeArm.at_ms : null,
        };
        events.casts.push(event);
        phase = "cock";
        cooldown = 0.32;
        resetStage(cockState);
        resetStage(snapState);
        activeArm = null;
      } else {
        firstFailure("snap", snapState, { index }, metrics, { final: gates.snap_threshold, axis: gates.direction_tolerance, polarity: gates.polarity_tolerance, gyro: gates.gyro_threshold }, elapsedMs, events.failures);
      }
    }
  }

  const lastFailure = events.failures.length ? events.failures[events.failures.length - 1] : null;
  return {
    index: cast.index,
    sample_count: cast.samples.length,
    arm_count: events.arms.length,
    cast_count: events.casts.length,
    arms: events.arms,
    casts: events.casts,
    failures: events.failures,
    outcome: events.casts.length ? "cast" : (lastFailure ? `${lastFailure.stage}:${lastFailure.reason}` : "no_qualified_sweep"),
  };
}

function dominantPhysicalLeftSnap(cast) {
  let dominant = null;
  for (let index = 0; index < cast.samples.length; index += 1) {
    const sample = cast.samples[index];
    const linear = Array.isArray(sample.linear) && sample.linear.length === 3 ? sample.linear : subtract(sample.accelerometer, sample.gravity);
    const leftProjection = -linear[0];
    if (!dominant || leftProjection > dominant.projection) {
      dominant = { at_ms: Number(sample.t_ms) - Number(cast.samples[0].t_ms), sample: index + 1, projection: leftProjection };
    }
  }
  return dominant;
}

function replayAsymmetricWindow(cast, metadata, gates, thresholdMultiplier, cockFactor, firstDelta, snapThresholdMultiplier = 1) {
  const profile = metadata.motion_profile;
  const leftHanded = metadata.handedness === "left";
  // This analysis is intentionally for the captured right-handed profile. The
  // left mirror is stated explicitly so the model cannot quietly analyze a
  // left-handed capture with a right-handed X sign.
  const cockSign = leftHanded ? -1 : 1;
  const forwardAxis = leftHanded ? [1, 0, 0] : [-1, 0, 0];
  const axis = normalize(profile.forward_axis);
  const physicalCockThreshold = gates.cock_threshold * thresholdMultiplier;
  const snapThreshold = gates.snap_threshold * snapThresholdMultiplier;
  const cockState = createStage();
  const snapState = createStage();
  const events = { arms: [], casts: [], failures: [] };
  const dominantLeft = dominantPhysicalLeftSnap(cast);
  let phase = "cock";
  let cooldown = 0;
  let reversalElapsed = 0;
  let priorT = null;
  let activeArm = null;
  for (let index = 0; index < cast.samples.length; index += 1) {
    const raw = cast.samples[index];
    const tMs = Number(raw.t_ms);
    const delta = priorT === null ? firstDelta : Math.max(0, (tMs - priorT) / 1000);
    priorT = tMs;
    cooldown = Math.max(0, cooldown - delta);
    if (cooldown > 0) continue;
    const linear = Array.isArray(raw.linear) && raw.linear.length === 3 ? raw.linear : subtract(raw.accelerometer, raw.gravity);
    const linearLength = magnitude(linear);
    const gyroLength = magnitude(raw.gyro);
    const normalized = normalize(linear);
    const elapsedMs = tMs - Number(cast.samples[0].t_ms);
    if (phase === "cock") {
      const projection = cockSign * linear[0];
      const metrics = {
        linearMagnitude: linearLength,
        gyroMagnitude: gyroLength,
        // Signed physical-X direction replaces only the cock's learned-axis
        // direction gate. Positive X is right/cock for this captured profile.
        axisMatch: linearLength > 0 ? cockSign * normalized[0] : -1,
        polarityMatch: linearLength > 0 ? cockSign * normalized[0] : -1,
      };
      const sweep = advanceSweep(cockState, projection, physicalCockThreshold, delta, cockFactor);
      if (sweep.ready && projection >= physicalCockThreshold) {
        if (!cockState.attemptLatched) cockState.attemptLatched = true;
        const accepted = metrics.axisMatch >= gates.polarity_tolerance && gyroLength >= gates.gyro_threshold;
        if (accepted) {
          const toDominantLeftMs = dominantLeft.at_ms - elapsedMs;
          const event = {
            at_ms: elapsedMs,
            sample: index + 1,
            projection: round(projection),
            impulse: round(cockState.impulse),
            samples: cockState.samples,
            physical_x_alignment: round(metrics.axisMatch),
            gyro: round(gyroLength),
            dominant_left_snap_in_ms: round(toDominantLeftMs, 1),
            timely_before_dominant_left: toDominantLeftMs >= 0 && toDominantLeftMs <= CONFIG.runtimeMaxReversalSeconds * 1000,
          };
          events.arms.push(event);
          activeArm = event;
          reversalElapsed = 0;
          phase = "snap";
        } else {
          firstFailure("cock", cockState, { index }, metrics, { final: physicalCockThreshold, axis: gates.polarity_tolerance, polarity: gates.polarity_tolerance, gyro: gates.gyro_threshold }, elapsedMs, events.failures);
        }
      }
      continue;
    }
    reversalElapsed += delta;
    if (reversalElapsed > CONFIG.runtimeMaxReversalSeconds) {
      events.failures.push({ stage: "snap", reason: "timeout", at_ms: elapsedMs, sample: index + 1 });
      phase = "cock";
      resetStage(cockState);
      resetStage(snapState);
      activeArm = null;
      continue;
    }
    const projection = dot(linear, axis);
    const metrics = {
      linearMagnitude: linearLength,
      gyroMagnitude: gyroLength,
      axisMatch: linearLength > 0 ? dot(normalized, axis) : -1,
      polarityMatch: linearLength > 0 ? dot(normalized, forwardAxis) : -1,
    };
    const sweep = advanceSweep(snapState, projection, snapThreshold, delta, 0.055);
    if (sweep.ready && projection >= snapThreshold) {
      if (!snapState.attemptLatched) snapState.attemptLatched = true;
      const accepted = metrics.axisMatch >= gates.direction_tolerance && metrics.polarityMatch >= gates.polarity_tolerance && gyroLength >= gates.gyro_threshold;
      if (accepted) {
        events.casts.push({ at_ms: elapsedMs, sample: index + 1, projection: round(projection), impulse: round(snapState.impulse), samples: snapState.samples, axis_match: round(metrics.axisMatch), polarity_match: round(metrics.polarityMatch), gyro: round(gyroLength), reversal_ms: round(reversalElapsed * 1000, 1), quality: round(quality(projection, snapThreshold, profile.forward_peak, reversalElapsed)), arm_at_ms: activeArm ? activeArm.at_ms : null });
        phase = "cock";
        cooldown = 0.32;
        resetStage(cockState);
        resetStage(snapState);
        activeArm = null;
      } else {
        firstFailure("snap", snapState, { index }, metrics, { final: snapThreshold, axis: gates.direction_tolerance, polarity: gates.polarity_tolerance, gyro: gates.gyro_threshold }, elapsedMs, events.failures);
      }
    }
  }
  const timelyArms = events.arms.filter(event => event.timely_before_dominant_left).length;
  const lastFailure = events.failures.length ? events.failures[events.failures.length - 1] : null;
  return {
    index: cast.index,
    sample_count: cast.samples.length,
    dominant_physical_left_snap: { at_ms: dominantLeft.at_ms, sample: dominantLeft.sample, projection: round(dominantLeft.projection) },
    arm_count: events.arms.length,
    timely_arm_count: timelyArms,
    cast_count: events.casts.length,
    arms: events.arms,
    casts: events.casts,
    failures: events.failures,
    outcome: events.casts.length ? "cast" : (lastFailure ? `${lastFailure.stage}:${lastFailure.reason}` : "no_qualified_sweep"),
  };
}

function windowSummary(cast, axis) {
  const back = [];
  const forward = [];
  const gyro = [];
  const linear = [];
  let mismatch = 0;
  for (const sample of cast.samples) {
    const reconstructed = subtract(sample.accelerometer, sample.gravity);
    const saved = Array.isArray(sample.linear) && sample.linear.length === 3 ? sample.linear : reconstructed;
    mismatch = Math.max(mismatch, magnitude(subtract(reconstructed, saved)));
    back.push(-dot(saved, axis));
    forward.push(dot(saved, axis));
    gyro.push(magnitude(sample.gyro));
    linear.push(magnitude(saved));
  }
  return { index: cast.index, back_max: round(Math.max(...back)), forward_max: round(Math.max(...forward)), gyro_max: round(Math.max(...gyro)), linear_max: round(Math.max(...linear)), saved_linear_max_error: round(mismatch, 7) };
}

function asymmetricEnvelope(cast, axis, metadata) {
  const leftHanded = metadata.handedness === "left";
  const cockSign = leftHanded ? -1 : 1;
  let cock = { projection: -Infinity, at_ms: 0, alignment: -1 };
  let snap = { projection: -Infinity, at_ms: 0, alignment: -1, physical_left: -Infinity };
  const start = Number(cast.samples[0].t_ms);
  for (const sample of cast.samples) {
    const linear = Array.isArray(sample.linear) && sample.linear.length === 3 ? sample.linear : subtract(sample.accelerometer, sample.gravity);
    const normalized = normalize(linear);
    const tMs = Number(sample.t_ms) - start;
    const cockProjection = cockSign * linear[0];
    if (cockProjection > cock.projection) cock = { projection: cockProjection, at_ms: tMs, alignment: cockSign * normalized[0] };
    const snapProjection = dot(linear, axis);
    if (snapProjection > snap.projection) snap = { projection: snapProjection, at_ms: tMs, alignment: dot(normalized, axis), physical_left: -cockSign * linear[0] };
  }
  const physicalLeft = dominantPhysicalLeftSnap(cast);
  return {
    index: cast.index,
    cock_right_peak: { projection: round(cock.projection), at_ms: cock.at_ms, physical_x_alignment: round(cock.alignment) },
    snap_learned_axis_peak: { projection: round(snap.projection), at_ms: snap.at_ms, learned_axis_alignment: round(snap.alignment), physical_left_projection: round(snap.physical_left) },
    dominant_physical_left_snap: { projection: round(physicalLeft.projection), at_ms: physicalLeft.at_ms },
  };
}

function analyze(inputPath) {
  const bytes = fs.readFileSync(inputPath);
  const inputSha256 = crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
  if (path.basename(inputPath) === V21_CAPTURE_FILENAME) {
    assert(inputSha256 === V21_CAPTURE_SHA256, `v21 capture SHA-256 differs from the reviewed evidence: ${inputSha256}`);
  }
  const capture = JSON.parse(bytes.toString("utf8"));
  assert(capture.version === 1, "expected capture schema version 1");
  assert(capture.completed === true, "capture is not marked completed");
  assert(Array.isArray(capture.casts) && capture.casts.length === 10, "expected exactly ten capture windows");
  assert(capture.metadata && capture.metadata.motion_profile, "missing motion profile metadata");
  const profile = capture.metadata.motion_profile;
  const axis = normalize(profile.forward_axis);
  assert(length(axis) > 0.9, "invalid learned forward axis");
  const intervals = [];
  for (const cast of capture.casts) {
    assert(Array.isArray(cast.samples) && cast.samples.length > 0, `cast ${cast.index} has no samples`);
    for (let i = 1; i < cast.samples.length; i += 1) {
      const dt = (Number(cast.samples[i].t_ms) - Number(cast.samples[i - 1].t_ms)) / 1000;
      if (dt > 0 && dt <= 0.2) intervals.push(dt);
    }
  }
  const firstDelta = median(intervals);
  assert(Number.isFinite(firstDelta) && firstDelta > 0, "could not derive a sane first-sample delta");
  const gates = runtimeGates(capture.metadata);
  const matrix = [];
  for (const cockFactor of COCK_FACTORS) {
    for (const snapFactor of SNAP_FACTORS) {
      const windows = capture.casts.map(cast => replayWindow(cast, capture.metadata, gates, cockFactor, snapFactor, firstDelta));
      matrix.push({
        cock_factor: cockFactor,
        snap_factor: snapFactor,
        accepted_windows: windows.filter(window => window.cast_count > 0).length,
        cast_events: windows.reduce((sum, window) => sum + window.cast_count, 0),
        cock_only_windows: windows.filter(window => window.arm_count > 0 && window.cast_count === 0).length,
        windows,
      });
    }
  }
  const baseline = matrix.find(row => row.cock_factor === 0.045 && row.snap_factor === 0.055);
  const asymmetricResults = [];
  for (const thresholdMultiplier of PHYSICAL_COCK_THRESHOLD_MULTIPLIERS) {
    for (const cockFactor of PHYSICAL_COCK_IMPULSE_FACTORS) {
      const windows = capture.casts.map(cast => replayAsymmetricWindow(cast, capture.metadata, gates, thresholdMultiplier, cockFactor, firstDelta));
      asymmetricResults.push({
        physical_cock_threshold_multiplier: thresholdMultiplier,
        physical_cock_threshold: round(gates.cock_threshold * thresholdMultiplier),
        physical_cock_impulse_factor: cockFactor,
        accepted_windows: windows.filter(window => window.cast_count > 0).length,
        timely_arm_windows: windows.filter(window => window.timely_arm_count > 0).length,
        cast_events: windows.reduce((sum, window) => sum + window.cast_count, 0),
        windows,
      });
    }
  }
  const bestAsymmetric = asymmetricResults.slice().sort((a, b) => {
    // Acceptance and timely arm coverage are primary. Among equivalently
    // successful variants, higher threshold then higher impulse is stricter.
    if (b.accepted_windows !== a.accepted_windows) return b.accepted_windows - a.accepted_windows;
    if (b.timely_arm_windows !== a.timely_arm_windows) return b.timely_arm_windows - a.timely_arm_windows;
    if (b.physical_cock_threshold_multiplier !== a.physical_cock_threshold_multiplier) return b.physical_cock_threshold_multiplier - a.physical_cock_threshold_multiplier;
    return b.physical_cock_impulse_factor - a.physical_cock_impulse_factor;
  })[0];
  const snapFinalThresholdResults = SNAP_FINAL_THRESHOLD_MULTIPLIERS.map(snapThresholdMultiplier => {
    const windows = capture.casts.map(cast => replayAsymmetricWindow(cast, capture.metadata, gates, 6.0, 0.045, firstDelta, snapThresholdMultiplier));
    const qualities = windows.flatMap(window => window.casts.map(event => event.quality));
    return {
      physical_cock_threshold_multiplier: 6.0,
      physical_cock_impulse_factor: 0.045,
      snap_threshold_multiplier: snapThresholdMultiplier,
      snap_final_threshold: round(gates.snap_threshold * snapThresholdMultiplier),
      accepted_windows: windows.filter(window => window.cast_count > 0).length,
      timely_arm_windows: windows.filter(window => window.timely_arm_count > 0).length,
      cast_events: windows.reduce((sum, window) => sum + window.cast_count, 0),
      quality_distribution: qualities.length ? descriptive(qualities) : null,
      windows,
    };
  });
  const strictestAllPassSnapThreshold = snapFinalThresholdResults.filter(row => row.accepted_windows === capture.casts.length && row.timely_arm_windows === capture.casts.length).sort((a, b) => b.snap_threshold_multiplier - a.snap_threshold_multiplier)[0] || null;
  const allBack = [];
  const allForward = [];
  const allGyro = [];
  const allLinear = [];
  const perWindow = capture.casts.map(cast => windowSummary(cast, axis));
  for (const cast of capture.casts) for (const sample of cast.samples) {
    const linear = Array.isArray(sample.linear) && sample.linear.length === 3 ? sample.linear : subtract(sample.accelerometer, sample.gravity);
    allBack.push(-dot(linear, axis));
    allForward.push(dot(linear, axis));
    allGyro.push(magnitude(sample.gyro));
    allLinear.push(magnitude(linear));
  }
  return {
    analyzer: "analyze_cast_capture.js",
    replay_model: "MotionService v21 runtime cast path; independent 2s capture windows",
    input: { filename: path.basename(inputPath), sha256: inputSha256, bytes: bytes.length },
    metadata: capture.metadata,
    timing: { first_sample_delta_seconds: round(firstDelta, 6), source: "median positive within-window t_ms delta", total_windows: capture.casts.length },
    gates: Object.fromEntries(Object.entries(gates).map(([key, value]) => [key, round(value, 6)])),
    constants: CONFIG,
    factor_grid: { cock: COCK_FACTORS, snap: SNAP_FACTORS, results: matrix },
    baseline_current_v21: baseline,
    descriptive: {
      all_samples: { back_projection: descriptive(allBack), forward_projection: descriptive(allForward), gyro_magnitude: descriptive(allGyro), linear_magnitude: descriptive(allLinear) },
      per_window: perWindow,
    },
    asymmetric_physical_cock: {
      candidate_target: "v22 0.3.9-castprofile1 source plan; not a physical v22 result",
      model: "right-handed cock: signed +X projection/alignment; snap: unchanged learned 3D forward axis",
      fixed_snap_impulse_factor: 0.055,
      threshold_multipliers: PHYSICAL_COCK_THRESHOLD_MULTIPLIERS,
      cock_impulse_factors: PHYSICAL_COCK_IMPULSE_FACTORS,
      results: asymmetricResults,
      strictest_best_variant: bestAsymmetric,
      per_window_direction_envelopes: capture.casts.map(cast => asymmetricEnvelope(cast, axis, capture.metadata)),
      snap_final_threshold_grid: {
        fixed_cock_threshold_multiplier: 6.0,
        fixed_cock_impulse_factor: 0.045,
        fixed_snap_impulse_factor: 0.055,
        snap_threshold_multipliers: SNAP_FINAL_THRESHOLD_MULTIPLIERS,
        results: snapFinalThresholdResults,
        strictest_all_pass_variant: strictestAllPassSnapThreshold,
      },
    },
  };
}

function compactFailures(window) {
  if (!window.failures.length) return "—";
  return window.failures.map(failure => `${failure.stage}:${failure.reason}@${failure.at_ms}ms`).join(", ");
}

function compactEvents(events, kind) {
  if (!events.length) return "—";
  return events.map(event => kind === "arm"
    ? `${event.at_ms}ms p${event.projection} i${event.impulse} n${event.samples}`
    : `${event.at_ms}ms p${event.projection} i${event.impulse} n${event.samples}; rev ${event.reversal_ms}ms; q${event.quality}`).join(" / ");
}

function markdown(result) {
  const baseline = result.baseline_current_v21;
  const grid = result.factor_grid.results;
  const rows = result.metadata.handedness === "left" ? "left-handed" : "right-handed";
  const count = (cock, snap) => grid.find(row => row.cock_factor === cock && row.snap_factor === snap).accepted_windows;
  const snapStability = SNAP_FACTORS.map(factor => ({ factor, counts: COCK_FACTORS.map(cock => count(cock, factor)) }));
  const failureTotals = baseline.windows.flatMap(window => window.failures).reduce((totals, failure) => {
    totals[failure.stage] = (totals[failure.stage] || 0) + 1;
    return totals;
  }, {});
  const maxByWindow = result.descriptive.per_window;
  const unchangedAtV18 = grid.filter(row => row.snap_factor === 0.055).map(row => row.accepted_windows);
  const asymmetric = result.asymmetric_physical_cock;
  const recommendedAsymmetric = asymmetric.strictest_best_variant;
  const snapFinalGrid = asymmetric.snap_final_threshold_grid;
  const strictestSnapFinal = snapFinalGrid.strictest_all_pass_variant;
  const allPassSnapFinal = snapFinalGrid.results.filter(row => row.accepted_windows === result.timing.total_windows && row.timely_arm_windows === result.timing.total_windows);
  const recommendation = unchangedAtV18.every(value => value === unchangedAtV18[0])
    ? `The evidence does not support raising the cock impulse: all tested cock factors produce ${unchangedAtV18[0]}/10 accepted windows while snap remains 0.055. Keep cock at the known v18 factor 0.045 and keep snap at 0.055; investigate final direction/gyro/timing only if the detailed replay identifies those gates.`
    : `Use the smallest cock factor that reaches the observed stable acceptance plateau with snap held at 0.055; do not raise snap unless its own grid column changes accepted outcomes.`;
  const lines = [];
  lines.push("# Pixel 9 Pro v21 explicit cast-capture replay");
  lines.push("");
  lines.push("## Evidence identity");
  lines.push("");
  lines.push(`- Input: \`${result.input.filename}\`, ${result.input.bytes.toLocaleString("en-US")} bytes, SHA-256 \`${result.input.sha256}\`.`);
  lines.push(`- Capture: schema v1, ${result.timing.total_windows} completed independent 2-second windows; ${rows}; sensitivity ${result.metadata.sensitivity}.`);
  lines.push(`- Replay first-sample delta: ${result.timing.first_sample_delta_seconds}s (median positive in-window \`t_ms\` delta); later deltas use adjacent timestamps and sweep integration caps each at ${CONFIG.runtimeSweepMaxDeltaSeconds}s.`);
  lines.push("- This report contains only derived projections, timing, thresholds, and outcomes. Raw vectors remain only in the explicitly user-started input capture.");
  lines.push("");
  lines.push("## Current v21 replay model");
  lines.push("");
  lines.push(`- Learned normalized forward axis: [${result.metadata.motion_profile.forward_axis.map(v => round(v, 6)).join(", ")}].`);
  lines.push(`- Gates: cock ${result.gates.cock_threshold}, snap ${result.gates.snap_threshold}, gyro ${result.gates.gyro_threshold}; learned-axis tolerance ${result.gates.direction_tolerance}, physical-polarity tolerance ${result.gates.polarity_tolerance}.`);
  lines.push(`- Shape: entry floor max(0.15, threshold × .35), at least 3 directed samples, each delta capped at .05s. Current factors: cock .045; snap .055. Final acceptance still requires threshold, learned-axis, physical-polarity, gyro, and .22s-full/.65s-fail reversal timing. A rejected qualified frame can recover later within its same directed burst.`);
  lines.push("");
  lines.push("## Factor grid — accepted windows / 10");
  lines.push("");
  lines.push("| Cock factor \\ snap factor | .055 | .0625 | .070 |");
  lines.push("|---:|---:|---:|---:|");
  for (const cock of COCK_FACTORS) lines.push(`| ${labelFactor(cock)} | ${SNAP_FACTORS.map(snap => count(cock, snap)).join(" | ")} |`);
  lines.push("");
  lines.push(`At the current v21 pair (.045/.055), ${baseline.accepted_windows}/10 windows emit a cast (${baseline.cast_events} cast event(s)); ${baseline.cock_only_windows}/10 arm but do not complete a snap.`);
  lines.push("");
  lines.push("## Current v21 per-window replay (.045 cock / .055 snap)");
  lines.push("");
  lines.push("| Window | Arms (time, projection, impulse, samples) | Casts (time, projection, impulse, samples, reversal, quality) | Result / first derived rejections |");
  lines.push("|---:|---|---|---|");
  for (const window of baseline.windows) lines.push(`| ${window.index} | ${compactEvents(window.arms, "arm")} | ${compactEvents(window.casts, "cast")} | ${window.outcome}; ${compactFailures(window)} |`);
  lines.push("");
  lines.push("## Natural trace envelope");
  lines.push("");
  const stats = result.descriptive.all_samples;
  lines.push("| Derived measure | p10 | p25 | p50 | p75 | p90 | max |");
  lines.push("|---|---:|---:|---:|---:|---:|---:|");
  for (const [label, values] of [["Back/right projection", stats.back_projection], ["Forward/left projection", stats.forward_projection], ["Gyro magnitude", stats.gyro_magnitude], ["Linear magnitude", stats.linear_magnitude]]) {
    lines.push(`| ${label} | ${values.p10} | ${values.p25} | ${values.p50} | ${values.p75} | ${values.p90} | ${values.max} |`);
  }
  lines.push("");
  lines.push("Per-window maxima and the bounded persistence-field reconstruction difference are retained in the machine-readable companion JSON. The replay uses the captured derived-linear field because CastCaptureService derives it before independently clamping persisted gravity/accelerometer/linear components; reconstructing it from two already-clamped source fields would distort saturated motion samples.");
  lines.push("");
  lines.push("## Failure split and recommendation");
  lines.push("");
  lines.push(`- Current-pair replay derived failures: cock ${failureTotals.cock || 0}, snap ${failureTotals.snap || 0}. A missing stage means no final qualified burst rather than a raw-sensor diagnosis.`);
  lines.push(`- ${recommendation}`);
  lines.push("- Scope caution: these are deliberately intended-positive ten-cast traces. They establish repeatability and show whether quiet/pre-motion portions create premature events, but they do **not** prove false-positive rejection for incidental movement. Keep wrong-direction/off-axis/noise trace tests and physical negative testing as separate evidence.");
  lines.push("");
  lines.push("## Asymmetric candidate: physical-X cock, learned-axis snap");
  lines.push("");
  lines.push("For this right-handed capture only, the candidate cock uses signed `+X` rightward projection and normalized `+X` alignment (minimum `.18`), instead of the learned profile-axis cock match. The forward snap retains the exact learned 3D axis, final snap threshold, direction/polarity/gyro gates, shape entry/count/cap, and `.055` snap impulse factor from v21.");
  lines.push("The selected physical-cock candidate is implemented in v22 source as a follow-up, but this report remains a replay of the v21 capture; it is not physical v22 evidence.");
  lines.push("");
  lines.push("| Physical cock threshold multiplier \\ impulse factor | .045 | .055 | .065 | .075 | .090 |");
  lines.push("|---:|---:|---:|---:|---:|---:|");
  for (const multiplier of PHYSICAL_COCK_THRESHOLD_MULTIPLIERS) {
    const cells = PHYSICAL_COCK_IMPULSE_FACTORS.map(factor => {
      const row = asymmetric.results.find(item => item.physical_cock_threshold_multiplier === multiplier && item.physical_cock_impulse_factor === factor);
      return `${row.accepted_windows}/${row.timely_arm_windows}`;
    });
    lines.push(`| ${labelFactor(multiplier)}× | ${cells.join(" | ")} |`);
  }
  lines.push("");
  lines.push("Each cell is `cast-accepted windows / windows with an arm 0–650ms before that window’s dominant physical-left (`-X`) snap`. This timing measure tests whether the cock is positioned in the actual reversal interval; it is not a false-positive test.");
  lines.push("");
  lines.push(`Using final amplitude threshold as the primary strictness dimension (then sweep energy), the strictest grid variant with the best observed intended-example coverage is **${labelFactor(recommendedAsymmetric.physical_cock_threshold_multiplier)}×** the current cock threshold (physical threshold ${recommendedAsymmetric.physical_cock_threshold}) and cock impulse **${labelFactor(recommendedAsymmetric.physical_cock_impulse_factor)}**. It accepts ${recommendedAsymmetric.accepted_windows}/10 windows and arms timely for ${recommendedAsymmetric.timely_arm_windows}/10. A 5×/.065 candidate is an all-pass higher-impulse alternative, but not a higher final-amplitude gate. Keep snap impulse at **.055**: this grid changes only cock treatment, and no snap-factor evidence supports tightening it.`);
  lines.push("");
  lines.push("## Snap final-threshold grid — fixed physical cock 6× / .045");
  lines.push("");
  lines.push("This grid fixes the selected physical cock at 6× the base cock threshold with .045 impulse. Every row retains the learned 3D snap axis, `.18` physical-polarity gate, `.60` gyro gate, three-sample sweep, `.055` snap impulse, and `.65s` reversal limit; only the snap **final amplitude threshold** is multiplied.");
  lines.push("");
  lines.push("| Snap threshold multiplier | Final threshold | Accepted / timely arms | Cast events |");
  lines.push("|---:|---:|---:|---:|");
  for (const row of snapFinalGrid.results) lines.push(`| ${labelFactor(row.snap_threshold_multiplier)}× | ${row.snap_final_threshold} | ${row.accepted_windows}/${row.timely_arm_windows} | ${row.cast_events} |`);
  lines.push("");
  if (strictestSnapFinal) {
    lines.push(`The strictest final snap threshold that still accepts and timely-arms all ten intended windows is **${labelFactor(strictestSnapFinal.snap_threshold_multiplier)}×** (final threshold ${strictestSnapFinal.snap_final_threshold}). The .055 snap impulse remains fixed; this is amplitude-only evidence.`);
  } else {
    lines.push("No tested final snap threshold both accepts and timely-arms all ten intended windows; do not raise the final snap gate from this capture alone.");
  }
  lines.push("");
  lines.push("| All-pass snap multiplier | Quality min | p10 | p25 | p50 | p75 | p90 | max |");
  lines.push("|---:|---:|---:|---:|---:|---:|---:|---:|");
  if (!allPassSnapFinal.length) {
    lines.push("| — | — | — | — | — | — | — | — |");
  } else {
    for (const row of allPassSnapFinal) {
      const q = row.quality_distribution;
      lines.push(`| ${labelFactor(row.snap_threshold_multiplier)}× | ${q.min} | ${q.p10} | ${q.p25} | ${q.p50} | ${q.p75} | ${q.p90} | ${q.max} |`);
    }
  }
  lines.push("");
  lines.push("These quality summaries are deterministic replay outputs, not player-feel evidence. Intended-positive examples alone cannot establish incidental-motion false-positive rejection.");
  lines.push("");
  lines.push("| Window | Right-cock envelope (peak projection / +X alignment / time) | Learned-axis snap envelope (peak projection / alignment / time) | Dominant physical-left snap (projection / time) |");
  lines.push("|---:|---|---|---|");
  for (const envelope of asymmetric.per_window_direction_envelopes) {
    const cock = envelope.cock_right_peak;
    const snap = envelope.snap_learned_axis_peak;
    const left = envelope.dominant_physical_left_snap;
    lines.push(`| ${envelope.index} | ${cock.projection} / ${cock.physical_x_alignment} / ${cock.at_ms}ms | ${snap.projection} / ${snap.learned_axis_alignment} / ${snap.at_ms}ms | ${left.projection} / ${left.at_ms}ms |`);
  }
  lines.push("");
  lines.push("## Reproduction");
  lines.push("");
  lines.push("```powershell");
  lines.push("node tools/analyze_cast_capture.js reports/device/pixel9pro-cast-capture-v21-2026-08-30.json reports/device/pixel9pro-cast-capture-v21-2026-08-30-analysis.json reports/device/pixel9pro-cast-capture-v21-2026-08-30-analysis.md");
  lines.push("```");
  lines.push("");
  return lines.join("\n");
}

function main() {
  const [inputArg, jsonArg, markdownArg] = process.argv.slice(2);
  const input = path.resolve(inputArg || DEFAULT_INPUT);
  const jsonOutput = path.resolve(jsonArg || DEFAULT_JSON);
  const markdownOutput = path.resolve(markdownArg || DEFAULT_MARKDOWN);
  const result = analyze(input);
  fs.mkdirSync(path.dirname(jsonOutput), { recursive: true });
  fs.mkdirSync(path.dirname(markdownOutput), { recursive: true });
  fs.writeFileSync(jsonOutput, `${JSON.stringify(result, null, 2)}\n`, "utf8");
  fs.writeFileSync(markdownOutput, markdown(result), "utf8");
  process.stdout.write(`Replay complete: ${result.baseline_current_v21.accepted_windows}/${result.timing.total_windows} current v21 windows accepted.\n`);
  process.stdout.write(`Wrote ${jsonOutput}\nWrote ${markdownOutput}\n`);
}

try {
  main();
} catch (error) {
  die(error && error.stack ? error.stack : String(error));
}

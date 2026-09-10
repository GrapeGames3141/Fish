class_name LocationDefinition
extends RefCounted

static func _make(location_id: String, label: String, real_region: String, kind: String, species: Array[String], hint: String, plate: String, atlas: String) -> Dictionary:
	return {"id": location_id, "title": label, "region": real_region, "water_type": kind, "species_ids": species, "habitat": hint, "plate_key": plate, "atlas_key": atlas}

static func all() -> Array:
	return [
		_make("willow_pond", "Willow Pond", "Hudson Valley, New York", "POND", ["pumpkinseed", "black_crappie", "brown_bullhead"], "Near lilies • shaded bank • pond drop", "willow", "willow"),
		_make("pine_lake", "Pine Lake", "Champlain Valley, Vermont", "LAKE", ["bluegill", "largemouth_bass", "channel_catfish"], "Near reeds • mid coves • far channel", "pine", "pine"),
		_make("cedar_river", "Cedar River", "Upper Peninsula, Michigan", "RIVER", ["rainbow_trout", "smallmouth_bass", "northern_pike"], "Near eddies • mid current • far run", "cedar", "cedar"),
		_make("hatteras_inlet", "Hatteras Inlet", "Outer Banks, North Carolina", "ATLANTIC INLET", ["red_drum", "spotted_seatrout", "bluefish"], "Near foam • tidal seam • outer channel", "hatteras", "ocean"),
		_make("mangrove_flats", "Mangrove Flats", "Ten Thousand Islands, Florida", "TIDAL FLATS", ["common_snook", "mangrove_snapper", "atlantic_tarpon"], "Root edge • clear flat • tidal cut", "mangrove", "mangrove"),
		_make("cypress_bayou", "Cypress Bayou", "Atchafalaya Basin, Louisiana", "BAYOU", ["bowfin", "longnose_gar", "flathead_catfish"], "Near roots • murky bend • deep pocket", "bayou", "bayou"),
		_make("moonlit_reservoir", "Moonlit Reservoir", "Ozark Plateau, Arkansas", "RESERVOIR", ["walleye", "striped_bass", "blue_catfish"], "Dock shadow • silver water • dam face", "moonlit", "moonlit"),
		_make("bluewater_offshore", "Bluewater Offshore", "Florida Straits", "BLUE WATER", ["mahi_mahi", "yellowfin_tuna", "atlantic_sailfish"], "Near slick • current line • bluewater", "offshore", "offshore")
	]

static func ids() -> Array[String]:
	var result: Array[String] = []
	for location in all(): result.append(location.id)
	return result

static func by_id(location_id: String) -> Dictionary:
	for location in all():
		if location.id == location_id: return location
	return {}

static func earlier_species(location_id: String) -> Array[String]:
	var result: Array[String] = []
	for location in all():
		if location.id == location_id: break
		result.append_array(location.species_ids)
	return result

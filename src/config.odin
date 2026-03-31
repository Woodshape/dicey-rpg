package game

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// --- Config parser ---
//
// Line-oriented parser for .cfg files. Fixed-size arrays, no heap allocation
// for parser internals. String values are slices into the raw file data.

MAX_CONFIG_SECTIONS :: 8
MAX_CONFIG_ENTRIES :: 16
MAX_CONFIG_ITEMS :: 8

Config_Entry :: struct {
	key:   string,
	value: string,
}

Config_Section :: struct {
	name:        string,
	entries:     [MAX_CONFIG_ENTRIES]Config_Entry,
	entry_count: int,
	items:       [MAX_CONFIG_ITEMS]string,
	item_count:  int,
	is_list:     bool,
}

Config_File :: struct {
	path:          string,
	root:          Config_Section, // entries before any [section] header
	sections:      [MAX_CONFIG_SECTIONS]Config_Section,
	section_count: int,
	_data:         []u8, // raw file data — keeps string slices valid
}

config_free :: proc(cf: ^Config_File) {
	delete(cf._data)
}

// Parse a .cfg file. Returns false on any error (logged via log.errorf).
config_parse_file :: proc(path: string) -> (Config_File, bool) {
	cf: Config_File
	cf.path = path

	data, ok := os.read_entire_file(path)
	if !ok {
		fmt.eprintfln("config error: %s: file not found", path)
		return cf, false
	}
	cf._data = data

	current_section: ^Config_Section = &cf.root
	line_num := 0
	content := string(data)

	for line in strings.split_lines_iterator(&content) {
		line_num += 1
		trimmed := strings.trim_space(line)

		// Skip blank lines and comments
		if len(trimmed) == 0 || trimmed[0] == '#' {
			continue
		}

		// Section header: [name]
		if trimmed[0] == '[' {
			end := strings.index_byte(trimmed, ']')
			if end < 0 {
				fmt.eprintfln("config error: %s:%d: unclosed section header", path, line_num)
				return cf, false
			}
			section_name := trimmed[1:end]

			// Check for duplicate section
			for i in 0 ..< cf.section_count {
				if cf.sections[i].name == section_name {
					fmt.eprintfln("config error: %s:%d: duplicate section [%s]", path, line_num, section_name)
					return cf, false
				}
			}

			if cf.section_count >= MAX_CONFIG_SECTIONS {
				fmt.eprintfln("config error: %s:%d: too many sections (max %d)", path, line_num, MAX_CONFIG_SECTIONS)
				return cf, false
			}

			cf.sections[cf.section_count].name = section_name
			current_section = &cf.sections[cf.section_count]
			cf.section_count += 1
			continue
		}

		// List item: - value
		if trimmed[0] == '-' && len(trimmed) > 1 && trimmed[1] == ' ' {
			if current_section.entry_count > 0 {
				fmt.eprintfln(
					"config error: %s:%d: list item in key-value section [%s]",
					path,
					line_num,
					current_section.name,
				)
				return cf, false
			}
			current_section.is_list = true

			if current_section.item_count >= MAX_CONFIG_ITEMS {
				fmt.eprintfln("config error: %s:%d: too many list items (max %d)", path, line_num, MAX_CONFIG_ITEMS)
				return cf, false
			}

			item := strings.trim_space(trimmed[2:])
			current_section.items[current_section.item_count] = item
			current_section.item_count += 1
			continue
		}

		// Key-value: key = value
		eq := strings.index_byte(trimmed, '=')
		if eq >= 0 {
			if current_section.is_list {
				fmt.eprintfln(
					"config error: %s:%d: key-value in list section [%s]",
					path,
					line_num,
					current_section.name,
				)
				return cf, false
			}

			key := strings.trim_space(trimmed[:eq])
			value := strings.trim_space(trimmed[eq + 1:])

			// Check for duplicate key in this section
			for i in 0 ..< current_section.entry_count {
				if current_section.entries[i].key == key {
					fmt.eprintfln(
						"config error: %s:%d: duplicate key '%s' in [%s]",
						path,
						line_num,
						key,
						current_section.name,
					)
					return cf, false
				}
			}

			if current_section.entry_count >= MAX_CONFIG_ENTRIES {
				fmt.eprintfln("config error: %s:%d: too many entries (max %d)", path, line_num, MAX_CONFIG_ENTRIES)
				return cf, false
			}

			current_section.entries[current_section.entry_count] = Config_Entry{key, value}
			current_section.entry_count += 1
			continue
		}

		fmt.eprintfln("config error: %s:%d: unrecognised line: %s", path, line_num, trimmed)
		return cf, false
	}

	return cf, true
}

// --- Config accessors ---

// Find a section by name. Returns nil if not found.
config_find_section :: proc(cf: ^Config_File, name: string) -> ^Config_Section {
	if name == "" {
		return &cf.root
	}
	for i in 0 ..< cf.section_count {
		if cf.sections[i].name == name {
			return &cf.sections[i]
		}
	}
	return nil
}

// Get a string value from a section. Empty string for root scope.
config_get_string :: proc(cf: ^Config_File, section, key: string) -> (string, bool) {
	s := config_find_section(cf, section)
	if s == nil {
		fmt.eprintfln("config error: %s: missing section [%s]", cf.path, section)
		return "", false
	}
	for i in 0 ..< s.entry_count {
		if s.entries[i].key == key {
			return s.entries[i].value, true
		}
	}
	fmt.eprintfln("config error: %s: [%s] missing key '%s'", cf.path, section, key)
	return "", false
}

// Get an optional integer value from a section. Returns fallback if key is absent.
config_get_int_or :: proc(cf: ^Config_File, section, key: string, fallback: int) -> int {
	s := config_find_section(cf, section)
	if s == nil {
		return fallback
	}
	for i in 0 ..< s.entry_count {
		if s.entries[i].key == key {
			val, parse_ok := strconv.parse_int(s.entries[i].value)
			if !parse_ok {
				fmt.eprintfln("config error: %s: [%s] key '%s' is not an integer: '%s'", cf.path, section, key, s.entries[i].value)
				return fallback
			}
			return val
		}
	}
	return fallback
}

// Get an integer value from a section.
config_get_int :: proc(cf: ^Config_File, section, key: string) -> (int, bool) {
	str, ok := config_get_string(cf, section, key)
	if !ok {
		return 0, false
	}
	val, parse_ok := strconv.parse_int(str)
	if !parse_ok {
		fmt.eprintfln("config error: %s: [%s] key '%s' is not an integer: '%s'", cf.path, section, key, str)
		return 0, false
	}
	return val, true
}

// Get list items from a section.
config_get_list :: proc(cf: ^Config_File, section: string) -> ([]string, bool) {
	s := config_find_section(cf, section)
	if s == nil {
		fmt.eprintfln("config error: %s: missing section [%s]", cf.path, section)
		return nil, false
	}
	if !s.is_list {
		fmt.eprintfln("config error: %s: [%s] is not a list section", cf.path, section)
		return nil, false
	}
	return s.items[:s.item_count], true
}

// --- Effect lookup tables ---
//
// Fixed arrays with linear search. Tables are tiny (< 10 entries each).
// Convention: the effect key auto-resolves to the same key in the describes table.

Effect_Entry :: struct {
	name:   string,
	effect: Ability_Effect,
}

Describe_Entry :: struct {
	name:     string,
	describe: Ability_Describe,
}

// Main ability effects
ABILITY_EFFECTS := [?]Effect_Entry {
	{"flurry", ability_flurry},
	{"smite", ability_smite},
	{"fireball", ability_fireball},
	{"heal", ability_heal},
	{"shield", ability_shield},
	{"hex", ability_hex},
}

ABILITY_DESCRIPTIONS := [?]Describe_Entry {
	{"flurry", describe_flurry},
	{"smite", describe_smite},
	{"fireball", describe_fireball},
	{"heal", describe_heal},
	{"shield", describe_shield},
	{"hex", describe_hex},
}

// Resolve ability effects
RESOLVE_EFFECTS := [?]Effect_Entry {
	{"resolve_warrior", ability_resolve_warrior},
	{"resolve_mass_heal", ability_resolve_mass_heal},
	{"resolve_goblin_explosion", ability_resolve_goblin_explosion},
	{"resolve_shaman_nuke", ability_resolve_shaman_nuke},
}

RESOLVE_DESCRIPTIONS := [?]Describe_Entry {
	{"resolve_warrior", describe_resolve_warrior},
	{"resolve_mass_heal", describe_resolve_mass_heal},
	{"resolve_goblin_explosion", describe_resolve_goblin_explosion},
	{"resolve_shaman_nuke", describe_resolve_shaman_nuke},
}

// Passive effect lookup tables
Passive_Entry :: struct {
	name:    string,
	trigger: Passive_Trigger,
	effect:  Passive_Effect,
}

PASSIVE_EFFECTS := [?]Passive_Entry {
	{"tenacity", .On_Roll, passive_tenacity},
	{"empathy", .On_Ally_Damaged, passive_empathy},
	{"scavenger", .On_Roll, passive_scavenger},
	{"curse_weaver", .On_Roll, passive_curse_weaver},
}

lookup_passive :: proc(name: string) -> (Passive_Entry, bool) {
	for &entry in PASSIVE_EFFECTS {
		if entry.name == name {
			return entry, true
		}
	}
	return {}, false
}

// Parse a passive trigger string into the enum value.
parse_trigger :: proc(s: string) -> (Passive_Trigger, bool) {
	switch s {
	case "none":
		return .None, true
	case "on_roll":
		return .On_Roll, true
	case "on_ally_damaged":
		return .On_Ally_Damaged, true
	}
	return .None, false
}

lookup_effect :: proc(name: string, table: []Effect_Entry) -> (Ability_Effect, bool) {
	for &entry in table {
		if entry.name == name {
			return entry.effect, true
		}
	}
	return nil, false
}

lookup_describe :: proc(name: string, table: []Describe_Entry) -> (Ability_Describe, bool) {
	for &entry in table {
		if entry.name == name {
			return entry.describe, true
		}
	}
	return nil, false
}

// Format valid effect names for error messages.
@(private = "file")
format_valid_effects :: proc(table: []Effect_Entry) -> string {
	// Use temp allocator — only lives for the error message
	parts: [16]string
	count := min(len(table), 16)
	for i in 0 ..< count {
		parts[i] = table[i].name
	}
	return strings.join(parts[:count], ", ", context.temp_allocator)
}

// --- Character loading ---

// Parse a rarity string into the enum value.
parse_rarity :: proc(s: string) -> (Character_Rarity, bool) {
	switch s {
	case "Common":
		return .Common, true
	case "Uncommon":
		return .Uncommon, true
	case "Rare":
		return .Rare, true
	case "Epic":
		return .Epic, true
	case "Legendary":
		return .Legendary, true
	}
	return .Common, false
}

// Parse a scaling string into the enum value.
parse_scaling :: proc(s: string) -> (Ability_Scaling, bool) {
	switch s {
	case "none":
		return .None, true
	case "match":
		return .Match, true
	case "value":
		return .Value, true
	case "hybrid":
		return .Hybrid, true
	}
	return .None, false
}

// Load an ability section from a parsed config file.
// effect_table/describe_table select which lookup tables to use (ability vs resolve).
// default_min_matches: 2 for main abilities, 0 for resolve abilities
load_ability_section :: proc(
	cf: ^Config_File,
	section: string,
	effect_table: []Effect_Entry,
	describe_table: []Describe_Entry,
	default_min_matches: int = 2,
) -> (ability: Ability, ok: bool) {

	name_str := config_get_string(cf, section, "name") or_return
	ability.name = strings.clone_to_cstring(name_str)

	effect_str := config_get_string(cf, section, "effect") or_return

	// "none" is valid for passive placeholder — returns a nil-effect ability
	if effect_str == "none" {
		ability.effect = nil
		ability.describe = nil
	} else {
		effect, found := lookup_effect(effect_str, effect_table)
		if !found {
			fmt.eprintfln(
				"config error: %s: [%s] unknown effect '%s' — valid: %s",
				cf.path,
				section,
				effect_str,
				format_valid_effects(effect_table),
			)
			return
		}
		ability.effect = effect

		// Convention-based describe resolution: same key
		describe, _ := lookup_describe(effect_str, describe_table)
		ability.describe = describe
	}

	scaling_str := config_get_string(cf, section, "scaling") or_return
	scaling, scaling_ok := parse_scaling(scaling_str)
	if !scaling_ok {
		fmt.eprintfln("config error: %s: [%s] unknown scaling '%s' — valid: none, match, value, hybrid", cf.path, section, scaling_str)
		return
	}
	ability.scaling = scaling

	ability.min_matches = config_get_int_or(cf, section, "min_matches", default_min_matches)
	ability.min_value = config_get_int_or(cf, section, "min_value", 0)
	ability.value_threshold = config_get_int_or(cf, section, "value_threshold", DEFAULT_VALUE_THRESHOLD)

	desc_str := config_get_string(cf, section, "description") or_return
	ability.description = strings.clone_to_cstring(desc_str)

	ok = true
	return
}

// Load a passive ability section from config.
load_passive_section :: proc(cf: ^Config_File) -> (passive: Passive, ok: bool) {

	name_str := config_get_string(cf, "passive", "name") or_return
	passive.name = strings.clone_to_cstring(name_str)

	effect_str := config_get_string(cf, "passive", "effect") or_return

	// "none" is valid — means no passive
	if effect_str == "none" {
		passive.effect = nil
		passive.trigger = .None
	} else {
		entry, found := lookup_passive(effect_str)
		if !found {
			// Format valid passive names for error message
			parts: [16]string
			count := min(len(PASSIVE_EFFECTS), 16)
			for i in 0 ..< count {
				parts[i] = PASSIVE_EFFECTS[i].name
			}
			valid := strings.join(parts[:count], ", ", context.temp_allocator)
			fmt.eprintfln(
				"config error: %s: [passive] unknown effect '%s' — valid: %s",
				cf.path, effect_str, valid,
			)
			return
		}
		passive.effect = entry.effect
		passive.trigger = entry.trigger
	}

	desc_str, desc_ok := config_get_string(cf, "passive", "description")
	if desc_ok {
		passive.description = strings.clone_to_cstring(desc_str)
	}

	ok = true
	return
}

// Load a character from data/characters/{name}.cfg.
config_load_character :: proc(name: string) -> (ch: Character, ok: bool) {
	path := fmt.tprintf("data/characters/%s.cfg", name)
	cf, parse_ok := config_parse_file(path)
	if !parse_ok {
		return
	}
	defer config_free(&cf)

	// Root fields
	char_name := config_get_string(&cf, "", "name") or_return
	rarity_str := config_get_string(&cf, "", "rarity") or_return
	resolve_max := config_get_int(&cf, "", "resolve_max") or_return

	rarity, rarity_ok := parse_rarity(rarity_str)
	if !rarity_ok {
		fmt.eprintfln(
			"config error: %s: unknown rarity '%s' — valid: Common, Rare, Epic, Legendary",
			path,
			rarity_str,
		)
		return
	}

	// Stats
	hp := config_get_int(&cf, "stats", "hp") or_return
	attack := config_get_int(&cf, "stats", "attack") or_return
	defense := config_get_int(&cf, "stats", "defense") or_return

	ch = character_create(
		strings.clone_to_cstring(char_name),
		rarity,
		Character_Stats{hp = hp, attack = attack, defense = defense},
	)
	ch.resolve_max = resolve_max

	// Abilities
	ch.ability = load_ability_section(&cf, "ability", ABILITY_EFFECTS[:], ABILITY_DESCRIPTIONS[:], 2) or_return
	ch.resolve_ability = load_ability_section(&cf, "resolve_ability", RESOLVE_EFFECTS[:], RESOLVE_DESCRIPTIONS[:], 0) or_return

	// Passive
	ch.passive = load_passive_section(&cf) or_return

	ok = true
	return
}

// Load an encounter from data/encounters/{name}.cfg.
// Returns player party, enemy party, and success bool.
config_load_encounter :: proc(name: string) -> (player_party: Party, enemy_party: Party, ok: bool) {
	path := fmt.tprintf("data/encounters/%s.cfg", name)
	cf, parse_ok := config_parse_file(path)
	if !parse_ok {
		return
	}
	defer config_free(&cf)

	// Load player side
	player_names := config_get_list(&cf, "player") or_return
	if len(player_names) > MAX_PARTY_SIZE {
		fmt.eprintfln("config error: %s: player party size %d exceeds max %d", path, len(player_names), MAX_PARTY_SIZE)
		return
	}
	for char_name, i in player_names {
		char, char_ok := config_load_character(char_name)
		if !char_ok {
			return
		}
		player_party.characters[i] = char
	}
	player_party.count = len(player_names)

	// Load enemy side
	enemy_names := config_get_list(&cf, "enemy") or_return
	if len(enemy_names) > MAX_PARTY_SIZE {
		fmt.eprintfln("config error: %s: enemy party size %d exceeds max %d", path, len(enemy_names), MAX_PARTY_SIZE)
		return
	}
	for char_name, i in enemy_names {
		char, char_ok := config_load_character(char_name)
		if !char_ok {
			return
		}
		enemy_party.characters[i] = char
	}
	enemy_party.count = len(enemy_names)

	ok = true
	return
}

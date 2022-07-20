tool
extends DialogicEvent
class_name DialogicChangeThemeEvent

# DEFINE ALL PROPERTIES OF THE EVENT
var ThemeName: String = ""

var TextMode = 0

# Multible boxes, by KvaGram.
# Mode 0 - one textbox, one name
# Default mode. Text event requires only 1 name. Text entered will only show on one box.
# Mode 1 - one textbox, more names
# Multible speakers. Text event requires secundary speaker(s). Text entered will only show on one box. multible name-boxes will be used.
# mode 2 - multible boxes, controlled by first
# Multible speakers with their own textboxes. Text event requires secundary speaker(s). Text entered will show multible lines at the same time, in their own boxes. Each box requires their own namebox.
# mode 3 - multible boxes that control themself with a timeout. Text event requires secundary speaker(s). Text entered will show multible lines at the same time. Each box requires their own namebox.
const text_modes_array:Dictionary = {"one textbox, one name":0, "one textbox, more names":1, "multible boxes, controlled by first":2, "multible boxes, detached with timeout":3}

func _execute() -> void:
	dialogic.Themes.change_theme(ThemeName)
	# base theme isn't overridden by character themes
	# these means after a charcter theme, we can change back to the base theme
	dialogic.current_state_info['base_theme'] = ThemeName
	finish()


func get_required_subsystems() -> Array:
	return [
				{'name':'Themes',
				'subsystem': get_script().resource_path.get_base_dir().plus_file('Subsystem_Themes.gd'),
				'character_main':get_script().resource_path.get_base_dir().plus_file('Theme_CharacterEdit.tscn')
				},
			]


################################################################################
## 						INITIALIZE
################################################################################

# SET ALL VALUES THAT SHOULD NEVER CHANGE HERE
func _init() -> void:
	event_name = "Change Theme"
	set_default_color('Color4')
	event_category = Category.AUDIOVISUAL
	event_sorting_index = 4
	


################################################################################
## 						SAVING/LOADING
################################################################################
func get_shortcode() -> String:
	return "theme"

func get_shortcode_parameters() -> Dictionary:
	return {
		#param_name : property_name
		"name"		: "ThemeName",
		"textmode"	: "TextMode"
	}


################################################################################
## 						EDITOR REPRESENTATION
################################################################################

func build_event_editor():
	add_header_edit('ThemeName', ValueType.SinglelineText, 'Name:')
	add_body_edit('TextMode', ValueType.FixedOptionSelector, 'Textbox mode', '', {'selector_options':text_modes_array}) #TODO: add link to documentation/tutorial

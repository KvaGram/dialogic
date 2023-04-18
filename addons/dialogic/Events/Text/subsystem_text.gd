extends DialogicSubsystem

## Subsystem that handles showing of dialog text (+text effects & modifiers), name label, and next indicator


signal text_finished(info:Dictionary)
signal speaker_updated(character:DialogicCharacter)
signal textbox_visibility_changed(visible:bool)

# used to color names without searching for all characters each time
var character_colors := {}
var color_regex := RegEx.new()
var text_already_read := false

var text_effects := {}
var parsed_text_effect_info : Array[Dictionary]= []
var text_effects_regex := RegEx.new()
var text_modifiers := []

var input_handler_node :Node = null


####################################################################################################
##					STATE
####################################################################################################

func clear_game_state() -> void:
	update_dialog_text('', true)
	update_name_label(null)
	dialogic.current_state_info['character'] = null
	dialogic.current_state_info['text'] = ''
	
	set_skippable(ProjectSettings.get_setting('dialogic/text/skippable', true))
	set_autoadvance(ProjectSettings.get_setting('dialogic/text/autoadvance', false), ProjectSettings.get_setting('dialogic/text/autocontinue_delay', 1))
	set_manualadvance(true)


func load_game_state() -> void:
	update_dialog_text(dialogic.current_state_info.get('text', ''), true)
	var character:DialogicCharacter = null
	if dialogic.current_state_info.get('character', null):
		character = load(dialogic.current_state_info.get('character', null))
	
	if character:
		update_name_label(character)


func pause() -> void:
	input_handler_node.pause()


func resume() -> void:
	input_handler_node.resume()


####################################################################################################
##					MAIN METHODS
####################################################################################################

## Shows the given text on all visible DialogText nodes.
## Instant can be used to skip all reveiling.
func update_dialog_text(text:String, instant:bool= false) -> String:
	text = parse_text_modifiers(text)
	text = parse_text_effects(text)
	text = color_names(text)
	
	if !instant: dialogic.current_state = dialogic.states.SHOWING_TEXT
	dialogic.current_state_info['text'] = text
	for text_node in get_tree().get_nodes_in_group('dialogic_dialog_text'):
		if text_node.is_visible_in_tree():
			if instant:
				text_node.text = text
			else:
				text_node.reveal_text(text)
				if !text_node.finished_revealing_text.is_connected(_on_dialog_text_finished):
					text_node.finished_revealing_text.connect(_on_dialog_text_finished)
	
	# also resets temporary autoadvance and noskip settings:
	set_autoadvance(false, 1, true)
	set_skippable(true, true)
	set_manualadvance(true, true)
	return text


func _on_dialog_text_finished():
	text_finished.emit({'text':dialogic.current_state_info['text'], 'character':dialogic.current_state_info['character']})


func update_name_label(character:DialogicCharacter) -> void:
	var character_path = character.resource_path if character else null
	if character_path == dialogic.current_state_info.get('character'):
		return
	for name_label in get_tree().get_nodes_in_group('dialogic_name_label'):
		if character:
			dialogic.current_state_info['character'] = character_path
			if dialogic.has_subsystem('VAR'):
				name_label.text = dialogic.VAR.parse_variables(character.display_name)
			else:
				name_label.text = character.display_name
			if !'use_character_color' in name_label or name_label.use_character_color:
				name_label.self_modulate = character.color
			speaker_updated.emit(character)
		else:
			dialogic.current_state_info['character'] = null
			name_label.text = ''
			name_label.self_modulate = Color(1,1,1,1)
			speaker_updated.emit(null)


func set_autoadvance(enabled:=true, wait_time:Variant=1.0, temp:= false) -> void:
	if !dialogic.current_state_info.has('autoadvance'):
		dialogic.current_state_info['autoadvance'] = {'enabled':false, 'temp_enabled':false, 'wait_time':0, 'temp_wait_time':0}
	if temp:
		dialogic.current_state_info['autoadvance']['temp_enabled'] = enabled
		dialogic.current_state_info['autoadvance']['temp_wait_time'] = wait_time
	else:
		dialogic.current_state_info['autoadvance']['enabled'] = enabled
		dialogic.current_state_info['autoadvance']['wait_time'] = wait_time

func set_manualadvance(enabled:=true, temp:= false) -> void:
	if !dialogic.current_state_info.has('manual_advance'):
		dialogic.current_state_info['manual_advance'] = {'enabled':true, 'temp_enabled':true}
	if temp:
		dialogic.current_state_info['manual_advance']['temp_enabled'] = enabled
	else:
		dialogic.current_state_info['manual_advance']['enabled'] = enabled


func set_skippable(skippable:= true, temp:=false) -> void:
	if !dialogic.current_state_info.has('skippable'):
		dialogic.current_state_info['skippable'] = {'enabled':false, 'temp_enabled':false}
	if temp:
		dialogic.current_state_info['skippable']['temp_enabled'] = skippable
	else:
		dialogic.current_state_info['skippable']['enabled'] = skippable


func update_typing_sound_mood(mood:Dictionary = {}) -> void:
	for typing_sound in get_tree().get_nodes_in_group('dialogic_type_sounds'):
		typing_sound.load_overwrite(mood)


func hide_text_boxes() -> void:
	for name_label in get_tree().get_nodes_in_group('dialogic_name_label'):
		name_label.text = ""
	for text_node in get_tree().get_nodes_in_group('dialogic_dialog_text'):
		text_node.get_parent().visible = false
	textbox_visibility_changed.emit(false)


func show_text_boxes() -> void:
	for text_node in get_tree().get_nodes_in_group('dialogic_dialog_text'):
		text_node.get_parent().visible = true
	textbox_visibility_changed.emit(true)


func show_next_indicators(question=false, autocontinue=false) -> void:
	for next_indicator in get_tree().get_nodes_in_group('dialogic_next_indicator'):
		if (question and 'show_on_questions' in next_indicator and next_indicator.show_on_questions) or \
			(autocontinue and 'show_on_autocontinue' in next_indicator and next_indicator.show_on_autocontinue) or (!question and !autocontinue):
			next_indicator.show()


func hide_next_indicators(fake_arg=null) -> void:
	for next_indicator in get_tree().get_nodes_in_group('dialogic_next_indicator'):
		next_indicator.hide()

####################################################################################################
##					HELPERS
####################################################################################################
func should_autoadvance() -> bool:
	return dialogic.current_state_info['autoadvance']['enabled'] or dialogic.current_state_info['autoadvance'].get('temp_enabled', false)


func can_manual_advance() -> bool:
	return dialogic.current_state_info['manual_advance']['enabled'] and dialogic.current_state_info['manual_advance'].get('temp_enabled', true)


func get_autoadvance_time() -> float:
	if dialogic.current_state_info['autoadvance'].get('temp_enabled', false):
		var wait_time:Variant = dialogic.current_state_info['autoadvance']['temp_wait_time']
		if typeof(wait_time) == TYPE_STRING and wait_time.begins_with('v'):
			if '+' in wait_time:
				return Dialogic.Voice.get_remaining_time() + float(wait_time.split('+')[1])
			return Dialogic.Voice.get_remaining_time()
		return float(dialogic.current_state_info['autoadvance']['temp_wait_time'])
	else:
		return float(dialogic.current_state_info['autoadvance']['wait_time'])


func get_autoadvance_progress() -> float:
	if !input_handler_node.is_autoadvancing():
		return -1
	return (get_autoadvance_time()-input_handler_node.get_autoadvance_time_left())/get_autoadvance_time()


func can_skip() -> bool:
	return dialogic.current_state_info['skippable']['enabled'] and dialogic.current_state_info['skippable'].get('temp_enabled', true)


func collect_text_effects() -> void:
	var text_effect_names := ""
	text_effects.clear()
	for indexer in DialogicUtil.get_indexers(true):
		for effect in indexer._get_text_effects():
			text_effects[effect.command] = {}
			if effect.has('subsystem') and effect.has('method'):
				text_effects[effect.command]['callable'] = Callable(Dialogic.get_subsystem(effect.subsystem), effect.method)
			elif effect.has('node_path') and effect.has('method'):
				text_effects[effect.command]['callable'] = Callable(get_node(effect.node_path), effect.method)
			else:
				continue
			text_effect_names += effect.command +"|"
	text_effects_regex.compile("(?<!\\\\)\\[\\s*(?<command>"+text_effect_names.trim_suffix("|")+")\\s*(=\\s*(?<value>.+?)\\s*)?\\]")


## Returns the string with all text effects removed
## Use get_parsed_text_effects() after calling this to get all effect information
func parse_text_effects(text:String) -> String:
	parsed_text_effect_info.clear()
	var position_correction := 0
	for effect_match in text_effects_regex.search_all(text):
		# append [index] = [command, value] to effects dict
		parsed_text_effect_info.append({'index':effect_match.get_start()-position_correction, 'execution_info':text_effects[effect_match.get_string('command')], 'value': effect_match.get_string('value').strip_edges()})
		
		## TODO MIGHT BE BROKEN, because I had to replace string.erase for godot 4
		text = text.substr(0,effect_match.get_start()-position_correction)+text.substr(effect_match.get_start()-position_correction+len(effect_match.get_string()))
		
		position_correction += len(effect_match.get_string())
	text = text.replace('\\[', '[')
	return text

func execute_effects(current_index:int, text_node:Control, skipping:bool= false) -> void:
	# might have to execute multiple effects
	while true:
		if parsed_text_effect_info.is_empty():
			return
		if current_index == -1 or current_index < parsed_text_effect_info[0]['index']:
			return
		var effect :Dictionary=  parsed_text_effect_info.pop_front()
		await (effect['execution_info']['callable'] as Callable).call(text_node, skipping, effect['value'])


func collect_text_modifiers() -> void:
	text_modifiers.clear()
	for indexer in DialogicUtil.get_indexers(true):
		for modifier in indexer._get_text_modifiers():
			if modifier.has('subsystem') and modifier.has('method'):
				text_modifiers.append(Callable(Dialogic.get_subsystem(modifier.subsystem), modifier.method))
			elif modifier.has('node_path') and modifier.has('method'):
				text_modifiers.append(Callable(get_node(modifier.node_path), modifier.method))


func parse_text_modifiers(text:String) -> String:
	for mod_method in text_modifiers:
		text = mod_method.call(text) 
	return text


func skip_text_animation() -> void:
	for text_node in get_tree().get_nodes_in_group('dialogic_dialog_text'):
		if text_node.is_visible_in_tree():
			text_node.finish_text()
	if dialogic.has_subsystem('Voice'):
		dialogic.Voice.stop_audio()


func get_current_speaker() -> DialogicCharacter:
	return (load(dialogic.current_state_info['character']) as DialogicCharacter)


func _ready():
	collect_character_names()
	collect_text_effects()
	collect_text_modifiers()
	Dialogic.event_handled.connect(hide_next_indicators)
	input_handler_node = Node.new()
	input_handler_node.set_script(load(get_script().resource_path.get_base_dir().path_join('default_input_handler.gd')))
	add_child(input_handler_node)


func color_names(text:String) -> String:
	if !DialogicUtil.get_project_setting('dialogic/text/autocolor_names', false):
		return text
	
	var counter := 0
	for result in color_regex.search_all(text):
		text = text.insert(result.get_start("name")+((9+8+8)*counter), '[color=#' + character_colors[result.get_string('name')].to_html() + ']')
		text = text.insert(result.get_end("name")+9+8+((9+8+8)*counter), '[/color]')
		counter += 1
	
	return text


func collect_character_names() -> void:
	#don't do this at all if we're not using autocolor names to begin with
	if !DialogicUtil.get_project_setting('dialogic/text/autocolor_names', false):
		return 
	
	character_colors = {}
	for dch_path in DialogicUtil.list_resources_of_type('.dch'):
		var dch := (load(dch_path) as DialogicCharacter)

		if dch.display_name:
			character_colors[dch.display_name] = dch.color
		
		for nickname in dch.nicknames:
			if nickname.strip_edges():
				character_colors[nickname.strip_edges()] = dch.color
	
	color_regex.compile('(?<=\\W|^)(?<name>'+str(character_colors.keys()).trim_prefix('["').trim_suffix('"]').replace('", "', '|')+')(?=\\W|$)')


################################################################################
## 				DEFAULT TEXT EFFECTS & MODIFIERS
################################################################################

func effect_pause(text_node:Control, skipped:bool, argument:String) -> void:
	if skipped:
		return
	if argument:
		await get_tree().create_timer(float(argument)).timeout
	else:
		await get_tree().create_timer(0.5).timeout


func effect_speed(text_node:Control, skipped:bool, argument:String) -> void:
	if skipped:
		return
	if argument:
		text_node.speed = float(argument)
	else:
		text_node.speed = DialogicUtil.get_project_setting('dialogic/text/speed', 0.01)


func effect_signal(text_node:Control, skipped:bool, argument:String) -> void:
	Dialogic.text_signal.emit(argument)


func effect_mood(text_node:Control, skipped:bool, argument:String) -> void:
	if argument.is_empty(): return
	if Dialogic.current_state_info.get('character', null):
		update_typing_sound_mood(
			load(Dialogic.current_state_info.character).custom_info.get('sound_moods', {}).get(argument, {}))


func effect_noskip(text_node:Control, skipped:bool, argument:String) -> void:
	set_skippable(false, true)
	set_manualadvance(false, true)
	effect_autoadvance(text_node, skipped, argument)


func effect_autoadvance(text_node:Control, skipped:bool, argument:String) -> void:
	if argument.is_empty() or !(argument.is_valid_float() or argument.begins_with('v')):
		set_autoadvance(true, ProjectSettings.get_setting('dialogic/text/autocontinue_delay', 1), true)
	else:
		set_autoadvance(true, argument, true)


var modifier_words_select_regex := RegEx.create_from_string("(?<!\\\\)\\[[^\\[\\]]+(\\/[^\\]]*)\\]")
func modifier_random_selection(text:String) -> String:
	for replace_mod_match in modifier_words_select_regex.search_all(text):
		var string :String= replace_mod_match.get_string().trim_prefix("[").trim_suffix("]")
		string = string.replace('//', '<slash>')
		var list :PackedStringArray= string.split('/')
		var item :String= list[randi()%len(list)]
		item = item.replace('<slash>', '/')
		text = text.replace(replace_mod_match.get_string(), item.strip_edges())
	return text


func modifier_break(text:String) -> String:
	return text.replace('[br]', '\n')

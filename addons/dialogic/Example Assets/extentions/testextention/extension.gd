@tool
extends Node
const example = "res://addons/dialogic_additions/Extensions/testextention/ExampleWindow.tscn" #example_tool

var editor_view:Control
var toolButton:Button

func setup():
	print("extention test")
	toolButton = Button.new()
	toolButton.text = "example"
	editor_view.find_child("Toolbar").get_node("Extentions").add_child(toolButton)
	toolButton.pressed.connect(onToolButton)
func onToolButton():
	print("Example extention!")

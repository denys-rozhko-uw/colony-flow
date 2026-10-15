class_name GameSnapshot
extends RefCounted

var tick: int = 0
var status: String = "PLAYING"
var cells: Array[String] = []
var slots: Array[String] = []
var boxes: Dictionary = {}
var jobs: Array[Dictionary] = []
var available_box_ids: Array[String] = []

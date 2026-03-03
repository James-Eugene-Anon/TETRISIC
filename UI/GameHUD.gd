extends Control

## 游戏HUD - 主游戏界面的所有HUD元素
## 包含分数、行数、预览、连击、装备、操作提示、计分规则等

@onready var score_label = $ScoreLabel
@onready var lines_label = $LinesLabel
@onready var next_label = $NextLabel
@onready var combo_label = $ComboLabel
@onready var equipment_label = $EquipmentLabel
@onready var controls_label = $ControlsLabel
@onready var scoring_label = $ScoringLabel
@onready var rift_meter_label = $RiftMeterLabel
@onready var beat_calibrator_label = $BeatCalibratorLabel
@onready var chinese_lyric_label = $ChineseLyricLabel

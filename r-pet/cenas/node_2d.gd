extends Node2D

var dragging = false
var drag_offset = Vector2i()
var gravity = 1200.0
var velocity_y = 0.0
var velocity_x = 80.0
var direcao: int = -1
var no_chao: bool = false
var AreaDesktop: Rect2i
var Janelas: Array[Rect2i] = []
var udp: PacketPeerUDP = PacketPeerUDP.new()
var udp_cmd: PacketPeerUDP = PacketPeerUDP.new()
var ColisaoLargura: int = 20

func _ready() -> void:
	AreaDesktop = DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())

	var err = udp.bind(4242)
	if err != OK:
		print("Erro ao tentar escutar a porta UDP: ", err)
	
	var err_cmd = udp_cmd.bind(4243)
	if err_cmd != OK:
		print("Erro ao tentar escutar a porta UDP: ", err_cmd)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = Vector2i(get_local_mouse_position())
			velocity_y = 0.0
		else:
			dragging = false

func _process(delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet().get_string_from_utf8()
		PegarJanelas(packet)
	
	while udp_cmd.get_available_packet_count() > 0:
		var cmd = udp_cmd.get_packet().get_string_from_utf8()
		ProcessaComando(cmd)
	
	var JanelaPet = get_window()
	
	if dragging:
		JanelaPet.position = DisplayServer.mouse_get_position() - drag_offset
		no_chao = false
		return
		
	velocity_y += gravity * delta
	var NovaPos_y = JanelaPet.position.y + int(velocity_y * delta)
		
	var PetCentro = JanelaPet.position.x + (JanelaPet.size.x / 2)
		
	@warning_ignore("integer_division")
	var PetLeft = PetCentro - (ColisaoLargura / 2)
	@warning_ignore("integer_division")
	var PetRight = PetCentro + (ColisaoLargura / 2)
		
	var chao_y = AreaDesktop.position.y + AreaDesktop.size.y - JanelaPet.size.y
	var floor_y = chao_y
	no_chao = false
		
	for Janela in Janelas:
		var JanelaTop: int = Janela.position.y
		var JanelaLeft: int = Janela.position.x
		var JanelaRight: int = JanelaLeft + Janela.size.x
		
		if PetRight > JanelaLeft and PetLeft < JanelaRight:
			var window_floor = JanelaTop - JanelaPet.size.y
			if window_floor < floor_y and JanelaPet.position.y <= window_floor:
				floor_y = window_floor
		
	if NovaPos_y >= floor_y:
		NovaPos_y = floor_y
		velocity_y = 0.0
		no_chao = true
	
	JanelaPet.position.y = NovaPos_y
	
	if no_chao:
		var NovaPos_x = JanelaPet.position.x + int(velocity_x * direcao * delta)
		var limite_esq = AreaDesktop.position.x
		var limite_dir = limite_esq + AreaDesktop.size.x - JanelaPet.size.x
		
		if NovaPos_x <= limite_esq:
			NovaPos_x = limite_esq
			direcao = 1
			AtualizaFlip()
		elif NovaPos_x >= limite_dir:
			NovaPos_x = limite_dir
			direcao = -1
			AtualizaFlip()
			
		JanelaPet.position.x = NovaPos_x

################################ PEGAR JANELAS #################################
func PegarJanelas(data: String):
	Janelas.clear()
	var JanelaPet = get_window()
	
	var screen_pos = DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	
	for ws in data.split("|", false):
		var coords = ws.split(",")
		if coords.size() != 4:
			continue
			
		var x1 = int(coords[0]) + screen_pos.x
		var y1 = int(coords[1]) + screen_pos.y
		var x2 = int(coords[2]) + screen_pos.x
		var y2 = int(coords[3]) + screen_pos.y
		
		if abs(x1 - JanelaPet.position.x) < 10 and abs(y1 - JanelaPet.position.y) < 10:
			continue
		
		var rect = Rect2i(x1, y1, x2 - x1, y2 - y1)
			
		Janelas.append(rect)

func Anima(nome: String) -> void:
	match nome:
		"andando": ColisaoLargura = 50

func AtualizaFlip() -> void:
	var sprite = $AnimatedSprite2D
	sprite.flip_h = (direcao == 1)

func ProcessaComando(cmd: String) -> void:
	var JanelaPet = get_window()
	
	match cmd:
		"CMD:fechar":
			get_tree().quit()
	

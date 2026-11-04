extends Control
var game: Node3D
var launch: Button
var action_button: Button
var orbit: Button
var up: Button
var down: Button

func setup(owner_game: Node3D) -> void:
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
	launch=_button("ПЛАНЕТА · АСТРА",game.start_planet_flight)
	action_button=_button("СПУСК",game.planet.action)
	orbit=_button("ВЫЙТИ НА ОРБИТУ",game.planet.exit_orbit)
	up=_button("ПОДЪЁМ ↑",func():pass)
	down=_button("СНИЖЕНИЕ ↓",func():pass)
	up.button_down.connect(func():game.planet.vertical=1.0)
	down.button_down.connect(func():game.planet.vertical=-1.0)
	up.button_up.connect(func():game.planet.vertical=0.0)
	down.button_up.connect(func():game.planet.vertical=0.0)

func _button(text: String, callback: Callable) -> Button:
	var b:=Button.new();b.text=text;game.flight_ui.decorate(b,true);b.pressed.connect(callback);add_child(b);return b
func rect(b: Button, r: Rect2) -> void:b.position=r.position;b.size=r.size
func modal() -> bool:return game.flight_ui.map_panel.visible or game.flight_ui.market_panel.visible or game.upgrades_panel.visible

func _process(_delta: float) -> void:
	if game==null:return
	size=game.flight_ui.design_size
	var portrait: bool=game.flight_ui.portrait
	rect(launch,Rect2(360,296,336,48) if portrait else Rect2(990,204,264,48))
	rect(orbit,Rect2(360,296,336,48) if portrait else Rect2(990,204,264,48))
	rect(action_button,Rect2(230,730,260,56) if portrait else Rect2(510,445,260,56))
	rect(up,Rect2(500,1040,196,64) if portrait else Rect2(1080,478,174,64))
	rect(down,Rect2(500,1116,196,64) if portrait else Rect2(1080,550,174,64))
	var blocked:=modal()
	var stage: String=game.mission.stage
	launch.visible=game.at_station() and game.pending_snapshot.is_empty() and not blocked
	var active: bool=game.planet.active() and not game.destroyed
	orbit.visible=active and stage=="ПОВЕРХНОСТЬ" and not blocked
	orbit.disabled=not game.planet.can_exit()
	up.visible=active and stage=="ПОВЕРХНОСТЬ" and not blocked
	down.visible=up.visible
	action_button.visible=active and stage in ["К ПЛАНЕТЕ","ПОВЕРХНОСТЬ","НА ПОВЕРХНОСТИ"] and not blocked
	if stage=="К ПЛАНЕТЕ":action_button.text="НАЧАТЬ СПУСК";action_button.disabled=not game.planet.can_enter()
	elif stage=="ПОВЕРХНОСТЬ":action_button.text="ПОСАДКА";action_button.disabled=not game.planet.can_land()
	else:action_button.text="ВЗЛЁТ";action_button.disabled=false
	queue_redraw()

func text_at(p: Vector2, value: String, font_size:=18, color:=Color("e9f5fc")) -> void:
	draw_string(get_theme_default_font(),p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _draw() -> void:
	if game==null or not game.planet.active() or modal() or game.destroyed:return
	var stage: String=game.mission.stage
	var portrait: bool=game.flight_ui.portrait
	if stage in ["СПУСК","ВЫХОД НА ОРБИТУ"]:
		var opacity:=clampf(sin(PI*minf(game.planet.elapsed,4.0)/4.0),0,1)
		draw_rect(Rect2(Vector2.ZERO,size),Color(.48,.63,.72,opacity))
		for i in range(6):
			var x:=fmod(i*280.0+game.planet.elapsed*140.0,size.x+400)-200
			draw_circle(Vector2(x,size.y*.45+sin(i*2.0)*120),200,Color(.8,.84,.87,opacity*.12))
		var center:=Vector2(size.x*.5-150,size.y*.5-28)
		draw_rect(Rect2(center-Vector2(24,28),Vector2(380,116)),Color(.025,.07,.11,.9))
		text_at(center,stage,23)
		text_at(center+Vector2(0,36),"Меридиан · %d%%" % mini(100,int(game.planet.elapsed/4.0*100)),18,Color("64e3ff"))
		return
	if stage not in ["К ПЛАНЕТЕ","ПОВЕРХНОСТЬ","ПОСАДКА","НА ПОВЕРХНОСТИ","ВЗЛЁТ"]:return
	var r:=Rect2(24,354,672,90) if portrait else Rect2(310,108,630,74)
	draw_style_box(game.flight_ui.style(Color(.025,.07,.11,.92),Color("285366")),r)
	var label: String
	var hint: String
	if stage=="К ПЛАНЕТЕ":
		label="АСТРА · ВХОД %d м" % int(game.ship.position.distance_to(game.planet.ENTRY))
		hint="Подойдите до 35 м, скорость до 25 м/с · затем «СПУСК»"
	else:
		label="МЕРИДИАН · ВЫСОТА %d м · %s" % [int(game.planet.altitude()),stage]
		if stage=="НА ПОВЕРХНОСТИ":hint="Посадка выполнена · нажмите «ВЗЛЁТ» для продолжения"
		elif stage in ["ПОСАДКА","ВЗЛЁТ"]:hint="Посадочная автоматика · управление временно передано"
		else:hint="Посадка: до 25 м, до 8 м/с · орбита: от 100 м"
	text_at(r.position+Vector2(18,27),label,16,Color("64e3ff"))
	text_at(r.position+Vector2(18,53),hint,15)

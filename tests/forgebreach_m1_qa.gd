extends SceneTree
## Independent M1 regression checks. No physical controller is involved.
## Runs in GitHub Actions, not in Fable's gameplay coding session.
##
## godot --headless --path . --script tests/forgebreach_m1_qa.gd

var passed := 0
var failed := 0


func _check(name: String, condition: bool) -> void:
    if condition:
        passed += 1
        print("  PASS  ", name)
    else:
        failed += 1
        print("  FAIL  ", name)


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
    if not InputMap.has_action(action):
        return false
    for candidate: InputEvent in InputMap.action_get_events(action):
        if candidate is InputEventJoypadButton and candidate.button_index == button:
            return true
    return false



func _has_axis(action: StringName, axis: JoyAxis, direction: float) -> bool:
    for candidate: InputEvent in InputMap.action_get_events(action):
        if candidate is InputEventJoypadMotion and candidate.axis == axis:
            if signf(candidate.axis_value) == signf(direction):
                return true
    return false


func _has_key(action: StringName, key: Key) -> bool:
    for candidate: InputEvent in InputMap.action_get_events(action):
        if candidate is InputEventKey and (candidate.keycode == key or candidate.physical_keycode == key):
            return true
    return false


func _ui_event_count() -> int:
    var total := 0
    for action: StringName in [&"ui_accept", &"ui_cancel", &"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
        total += InputMap.action_get_events(action).size()
    return total


func _pad_button(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
    var event := InputEventJoypadButton.new()
    event.device = 0
    event.button_index = button
    event.pressed = pressed
    return event


func _initialize() -> void:
    await process_frame
    InputActions.ensure()
    print("\n== FORGEBREACH M1 controller-first QA ==")
    _check("1280x720 design viewport", 
        int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1280
        and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 720)
    _check("gamepad X bound to light", _has_joy_button(InputActions.LIGHT, JOY_BUTTON_X))
    _check("gamepad Y bound to heavy", _has_joy_button(InputActions.HEAVY, JOY_BUTTON_Y))
    _check("gamepad B bound to dodge", _has_joy_button(InputActions.DODGE, JOY_BUTTON_B))
    _check("gamepad LB bound to guard", _has_joy_button(InputActions.GUARD, JOY_BUTTON_LEFT_SHOULDER))
    _check("gamepad Menu/Start bound to pause", _has_joy_button(InputActions.PAUSE, JOY_BUTTON_START))
    _check("gamepad A bound to built-in menu confirmation", _has_joy_button(&"ui_accept", JOY_BUTTON_A))
    _check("right-stick aim actions are registered", InputMap.has_action(InputActions.AIM_LEFT)
        and InputMap.has_action(InputActions.AIM_RIGHT)
        and InputMap.has_action(InputActions.AIM_UP)
        and InputMap.has_action(InputActions.AIM_DOWN))

    var main := load("res://scenes/main.tscn") as PackedScene
    var g := main.instantiate() as Game
    root.add_child(g)
    _check("desktop hides legacy touch controls", not g.touch_ui and not g.controls.visible)
    _check("title screen uses the new title", g.menu._title.text == "FORGEBREACH")
    g.start_fight(Game.Mode.ONE)
    _check("one-enemy arena can start", g.state == Game.State.FIGHTING
        and g.enemies_alive() == 1 and g.hero.hp == g.tuning.hero_max_hp)

    # Input is injected directly into the game's event handler (not a physical pad).
    # This covers InputMap dispatch and Hero's initial committed attack state.
    g._input(_pad_button(JOY_BUTTON_X, true))
    g.step(1.0 / 60.0)
    _check("gamepad X starts an immediate light attack", 
        g.hero.state == Hero.State.WINDUP and not bool(g.hero.cur_attack.get("heavy", true)))
    g.start_fight(Game.Mode.ONE)
    g._input(_pad_button(JOY_BUTTON_Y, true))
    g.step(1.0 / 60.0)
    _check("gamepad Y starts separate committed heavy attack",
        g.hero.state == Hero.State.WINDUP and bool(g.hero.cur_attack.get("heavy", false)))

    g.start_fight(Game.Mode.ONE)
    var before := g.hero.position
    g.input.aim = Vector2.RIGHT
    g.step(1.0 / 60.0)
    var expected := Iso.stick_to_ground(Vector2.RIGHT).normalized()
    _check("right stick turns without moving", 
        g.hero.facing.distance_to(expected) < 0.01 and g.hero.position.distance_to(before) < 0.01)
    g.input.aim = Vector2.ZERO
    g.step(1.0 / 60.0)
    _check("neutral right stick retains facing", g.hero.facing.distance_to(expected) < 0.01)

    g.start_fight(Game.Mode.ONE)
    g._input(_pad_button(JOY_BUTTON_LEFT_SHOULDER, true))
    g.step(1.0 / 60.0)
    _check("LB raises guard", g.hero.is_guarding())
    g._input(_pad_button(JOY_BUTTON_LEFT_SHOULDER, false))
    g.step(1.0 / 60.0)
    _check("releasing LB drops guard", not g.hero.is_guarding())

    g.start_fight(Game.Mode.ONE)
    g._input(_pad_button(JOY_BUTTON_B, true))
    g.step(1.0 / 60.0)
    _check("B begins dodge", g.hero.state == Hero.State.DODGE)

    g.start_fight(Game.Mode.ONE)
    var time_before := g.fight_time
    g.pause_game()
    g.step(0.1)
    _check("pause freezes simulation clock", g.paused and is_equal_approx(g.fight_time, time_before))
    g.resume_game()
    _check("resume returns to active combat", not g.paused and g.state == Game.State.FIGHTING)

    g.input.press_attack(false)
    g._on_joy_connection_changed(0, false)
    _check("disconnect pauses and clears held input", 
        g.paused and not g.input.attack_down() and g.input.key_move == Vector2.ZERO)
    g.resume_game()
    g.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    _check("focus loss pauses and clears input", g.paused and not g.input.block_down())

    g.return_to_menu()
    _check("return to loadout clears the encounter", 
        g.state == Game.State.MENU and g.menu.visible and g.enemies.is_empty())
    # Keep Game alive until menu activation assertion at the end.
    # Explicit clean-up occurs after those tests.

    # New explicit action-map contract, unlike the older engine-default assumptions.
    _check("gamepad B bound to cancel", _has_joy_button(&"ui_cancel", JOY_BUTTON_B))
    _check("D-pad left bound to ui_left", _has_joy_button(&"ui_left", JOY_BUTTON_DPAD_LEFT))
    _check("D-pad right bound to ui_right", _has_joy_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT))
    _check("D-pad up bound to ui_up", _has_joy_button(&"ui_up", JOY_BUTTON_DPAD_UP))
    _check("D-pad down bound to ui_down", _has_joy_button(&"ui_down", JOY_BUTTON_DPAD_DOWN))
    _check("left-stick axes bound to navigation", _has_axis(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
        and _has_axis(&"ui_right", JOY_AXIS_LEFT_X, 1.0)
        and _has_axis(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
        and _has_axis(&"ui_down", JOY_AXIS_LEFT_Y, 1.0))
    var ui_before := _ui_event_count()
    InputActions.ensure()
    InputActions.ensure()
    _check("ensure called twice adds no duplicate menu bindings", _ui_event_count() == ui_before)
    _check("Space not accepted by UI but still a combat dodge", 
        not _has_key(&"ui_accept", KEY_SPACE) and _has_key(InputActions.DODGE, KEY_SPACE))
    _check("Enter is available for menu confirmation", _has_key(&"ui_accept", KEY_ENTER))

    # Isolated MenuPanel: test its two-stage Quit guard without invoking Game's
    # real get_tree().quit() listener.
    var menu := MenuPanel.new()
    root.add_child(menu)
    var quit_calls := [0]
    menu.quit_requested.connect(func(): quit_calls[0] += 1)
    _check("Quit starts disarmed", not menu._quit_armed and menu._quit_button.text == "Quit to desktop")
    menu._quit_button.pressed.emit()
    _check("first Quit press arms but does not exit", quit_calls[0] == 0 and menu._quit_armed)
    menu._quit_button.pressed.emit()
    _check("second consecutive Quit press emits once", quit_calls[0] == 1)
    menu.show_start()
    menu._quit_button.pressed.emit()
    menu._quit_button.focus_exited.emit()
    menu._quit_button.pressed.emit()
    _check("focus loss disarms Quit confirmation", quit_calls[0] == 1 and menu._quit_armed)
    menu.show_result(true, 15.0, 50.0, Game.Mode.ONE, "Sword")
    _check("showing a result disarms Quit", not menu._quit_armed)
    menu.queue_free()

    # Test true first-launch title focus in a fresh Game, independently of
    # focus left on the prior test's returning-from-fight menu.
    g.queue_free()
    await process_frame
    var title_game := main.instantiate() as Game
    root.add_child(title_game)
    await process_frame
    await process_frame
    var focus := root.gui_get_focus_owner()
    print("  INFO  fresh title focus owner: ", focus.get_path() if focus != null else "<none>")
    _check("Fight has controller navigation focus on first title screen",
        focus == title_game.menu._fight_button)
    # A synthetic UI press must use Godot's GUI event handling, not an explicit
    # Button.pressed.emit(). This is not physical controller evidence.
    Input.parse_input_event(_pad_button(JOY_BUTTON_A, true))
    await process_frame
    Input.parse_input_event(_pad_button(JOY_BUTTON_A, false))
    await process_frame
    _check("synthetic gamepad A activates focused Fight", title_game.state == Game.State.FIGHTING)
    title_game.queue_free()

    print("\nM1 independent QA: ", passed, " passed; ", failed, " failed.")
    quit(1 if failed > 0 else 0)

extends SceneTree
func _init():
    if "playback_speed_scale" in AudioServer:
        print("YES playback_speed_scale EXISTS")
    else:
        print("NO playback_speed_scale")
    quit()

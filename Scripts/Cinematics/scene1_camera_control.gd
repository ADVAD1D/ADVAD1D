extends Camera2D

@export var scroll_speed: float = 15.0
@export var breath_amplitude: float = 50.0 # Qué tan arriba y abajo se mueve
@export var breath_speed: float = 1.0    # Qué tan rápido lo hace

# Guardaremos la posición Y base para el scroll
var scroll_y_position: float = 0.0

func _ready() -> void:
	# Al empezar, guardamos la posición Y inicial
	scroll_y_position = position.y

func _process(delta: float) -> void:
	# 1. Actualizamos la base del scroll (el movimiento constante hacia abajo)
	scroll_y_position += scroll_speed * delta
	
	# 2. Calculamos el desplazamiento de la "respiración" con la onda senoidal
	var breath_offset = sin(Time.get_ticks_msec() * 0.001 * breath_speed) * breath_amplitude
	
	# 3. Aplicamos AMBOS a la posición final de la cámara
	position.y = scroll_y_position + breath_offset

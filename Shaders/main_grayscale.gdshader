shader_type canvas_item;

// Esta es la variable que nuestro Tween va a controlar (de 0.0 a 1.0)
uniform float grayscale_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    // Fórmula matemática para la luminiscencia (escala de grises)
    float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114)); 
    // Mezclamos el color original con el gris según el grayscale_amount
    COLOR.rgb = mix(tex_color.rgb, vec3(gray), grayscale_amount);
    COLOR.a = tex_color.a;
}
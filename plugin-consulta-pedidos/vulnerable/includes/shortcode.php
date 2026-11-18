<?php
defined( 'ABSPATH' ) || exit;

add_shortcode( 'consulta_pedidos', 'cp_shortcode' );

function cp_shortcode() {
	if ( ! is_user_logged_in() ) {
		return '<p>Inicia sesión para consultar tus pedidos.</p>';
	}

	$html = '';
	if ( isset( $_POST['cp_pedido'], $_POST['cp_comentario'] ) ) {
		// Vulnerable intencional: sin nonce (CSRF), sin validar el dueño y el texto se guarda sin sanitizar.
		cp_agregar_comentario( $_POST['cp_pedido'], $_POST['cp_comentario'] );
		$html .= '<p>Comentario agregado.</p>';
	}

	$buscado = isset( $_GET['pedido'] ) ? wp_unslash( $_GET['pedido'] ) : '';

	// Vulnerable intencional: el valor buscado se imprime sin escapar (XSS reflejado).
	$html .= '<form method="get">
		<label>Número de pedido <input type="text" name="pedido" value="' . $buscado . '"></label>
		<button type="submit">Consultar</button>
	</form>';

	if ( '' === $buscado ) {
		return $html;
	}

	$html  .= "<h3>Resultado para el pedido $buscado</h3>";
	$pedido = cp_obtener_pedido( $buscado );
	if ( is_wp_error( $pedido ) ) {
		return $html . '<p>' . $pedido->get_error_message() . '</p>';
	}
	if ( ! $pedido ) {
		return $html . '<p>No se encontró el pedido.</p>';
	}

	// Vulnerable intencional: muestra pedidos de cualquier cliente y sin escapar sus datos.
	$html .= '<table>';
	foreach ( $pedido as $campo => $valor ) {
		$html .= "<tr><th>$campo</th><td>$valor</td></tr>";
	}
	$html .= '</table><h4>Comentarios</h4><ul>';
	foreach ( cp_comentarios( $pedido['id'] ) as $comentario ) {
		// Vulnerable intencional: el comentario guardado se imprime tal cual (XSS almacenado).
		$html .= "<li>$comentario</li>";
	}
	$html .= '</ul>';

	$html .= '<form method="post">
		<input type="hidden" name="cp_pedido" value="' . $pedido['id'] . '">
		<label>Agregar comentario <textarea name="cp_comentario"></textarea></label>
		<button type="submit">Enviar</button>
	</form>';

	return $html;
}

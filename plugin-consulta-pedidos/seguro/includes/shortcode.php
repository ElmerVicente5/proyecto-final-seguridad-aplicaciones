<?php
defined( 'ABSPATH' ) || exit;

const CP_MAX_COMENTARIO = 500;

add_shortcode( 'consulta_pedidos', 'cp_shortcode' );

function cp_shortcode() {
	if ( ! is_user_logged_in() ) {
		return '<p>Inicia sesión para consultar tus pedidos.</p>';
	}

	$usuario = wp_get_current_user();
	$html    = '';
	if ( isset( $_POST['cp_pedido'] ) ) {
		$html .= '<p>' . esc_html( cp_procesar_comentario( $usuario ) ) . '</p>';
	}

	$buscado = isset( $_GET['pedido'] ) ? absint( $_GET['pedido'] ) : 0;

	$html .= '<form method="get">
		<label>Número de pedido <input type="number" min="1" name="pedido" value="' . esc_attr( $buscado ? $buscado : '' ) . '"></label>
		<button type="submit">Consultar</button>
	</form>';

	if ( ! $buscado ) {
		return $html;
	}

	$pedido = cp_obtener_pedido( $buscado );
	if ( ! cp_puede_ver( $usuario, $pedido ) ) {
		return $html . '<p>No se encontró el pedido.</p>';
	}

	$html .= '<h3>' . esc_html( sprintf( 'Resultado para el pedido %d', $buscado ) ) . '</h3><table>';
	foreach ( cp_vista_pedido( $usuario, $pedido ) as $campo => $valor ) {
		$html .= '<tr><th>' . esc_html( $campo ) . '</th><td>' . esc_html( $valor ) . '</td></tr>';
	}
	$html .= '</table><h4>Comentarios</h4><ul>';
	foreach ( cp_comentarios( $pedido['id'] ) as $comentario ) {
		$html .= '<li>' . nl2br( esc_html( $comentario ) ) . '</li>';
	}
	$html .= '</ul>';

	$html .= '<form method="post">'
		. wp_nonce_field( 'cp_comentar_' . $pedido['id'], 'cp_nonce', true, false )
		. '<input type="hidden" name="cp_pedido" value="' . esc_attr( $pedido['id'] ) . '">
		<label>Agregar comentario <textarea name="cp_comentario" maxlength="' . CP_MAX_COMENTARIO . '"></textarea></label>
		<button type="submit">Enviar</button>
	</form>';

	return $html;
}

/**
 * Valida y guarda un comentario; devuelve el mensaje para el usuario.
 */
function cp_procesar_comentario( WP_User $usuario ) {
	$pedido_id = absint( $_POST['cp_pedido'] );
	$nonce     = isset( $_POST['cp_nonce'] ) ? sanitize_text_field( wp_unslash( $_POST['cp_nonce'] ) ) : '';

	// El nonce confirma que el formulario salió de esta página y no de un sitio externo (CSRF).
	if ( ! wp_verify_nonce( $nonce, 'cp_comentar_' . $pedido_id ) ) {
		return 'La solicitud no es válida. Recarga la página e intenta de nuevo.';
	}
	if ( ! cp_puede_ver( $usuario, cp_obtener_pedido( $pedido_id ) ) ) {
		return 'No se encontró el pedido.';
	}

	$texto = isset( $_POST['cp_comentario'] ) ? sanitize_textarea_field( wp_unslash( $_POST['cp_comentario'] ) ) : '';
	$texto = mb_substr( $texto, 0, CP_MAX_COMENTARIO );
	if ( '' === $texto ) {
		return 'Escribe un comentario.';
	}

	cp_agregar_comentario( $pedido_id, $texto );
	return 'Comentario agregado.';
}

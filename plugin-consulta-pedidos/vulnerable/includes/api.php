<?php
defined( 'ABSPATH' ) || exit;

add_action( 'rest_api_init', 'cp_registrar_rutas' );

function cp_registrar_rutas() {
	$rutas = array(
		'/token'   => array( 'POST', 'cp_api_token' ),
		'/pedido'  => array( 'GET', 'cp_api_pedido' ),
		'/pedidos' => array( 'GET', 'cp_api_pedidos' ),
	);
	foreach ( $rutas as $ruta => list( $metodo, $funcion ) ) {
		register_rest_route(
			'consulta-pedidos/v1',
			$ruta,
			array(
				'methods'             => $metodo,
				'callback'            => $funcion,
				'permission_callback' => '__return_true',
			)
		);
	}
}

function cp_api_token( WP_REST_Request $request ) {
	// Vulnerable intencional: no limita los intentos, permite fuerza bruta.
	$usuario = wp_authenticate( $request->get_param( 'usuario' ), $request->get_param( 'clave' ) );
	if ( is_wp_error( $usuario ) ) {
		// Vulnerable intencional: el mensaje de WordPress revela si el usuario existe.
		return new WP_Error( 'cp_login', wp_strip_all_tags( $usuario->get_error_message() ), array( 'status' => 401 ) );
	}
	return array( 'token' => cp_emitir_token( $usuario ) );
}

function cp_api_pedido( WP_REST_Request $request ) {
	$datos = cp_datos_token( $request );
	if ( is_wp_error( $datos ) ) {
		return $datos;
	}
	if ( ! $datos ) {
		return new WP_Error( 'cp_auth', 'Se requiere un token.', array( 'status' => 401 ) );
	}

	// Vulnerable intencional: no verifica que el pedido sea del usuario del token (IDOR).
	$pedido = cp_obtener_pedido( $request->get_param( 'id' ) );
	if ( is_wp_error( $pedido ) ) {
		return $pedido;
	}
	if ( ! $pedido ) {
		return new WP_Error( 'cp_no_existe', 'El pedido no existe.', array( 'status' => 404 ) );
	}
	return $pedido;
}

function cp_api_pedidos( WP_REST_Request $request ) {
	$datos = cp_datos_token( $request );
	if ( is_wp_error( $datos ) ) {
		return $datos;
	}
	if ( ! $datos ) {
		return new WP_Error( 'cp_auth', 'Se requiere un token.', array( 'status' => 401 ) );
	}

	$cliente_id = cp_es_gestor( $datos ) ? 0 : (int) $datos->sub;
	// Vulnerable intencional: por_pagina no tiene tope, permite descargar todos los pedidos de una vez.
	return cp_listar_pedidos(
		$cliente_id,
		$request->get_param( 'pagina' ) ?: 1,
		$request->get_param( 'por_pagina' ) ?: 10,
		$request->get_param( 'orden' ) ?: 'p.ID DESC'
	);
}

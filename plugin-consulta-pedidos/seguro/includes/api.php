<?php
defined( 'ABSPATH' ) || exit;

const CP_MAX_INTENTOS   = 5;
const CP_BLOQUEO        = 900;
const CP_MAX_POR_PAGINA = 20;

add_action( 'rest_api_init', 'cp_registrar_rutas' );

function cp_registrar_rutas() {
	register_rest_route(
		'consulta-pedidos/v1',
		'/token',
		array(
			'methods'             => 'POST',
			'callback'            => 'cp_api_token',
			'permission_callback' => '__return_true',
			'args'                => array(
				'usuario' => array(
					'type'     => 'string',
					'required' => true,
				),
				'clave'   => array(
					'type'     => 'string',
					'required' => true,
				),
			),
		)
	);

	register_rest_route(
		'consulta-pedidos/v1',
		'/pedido',
		array(
			'methods'             => 'GET',
			'callback'            => 'cp_api_pedido',
			'permission_callback' => 'cp_permiso_token',
			'args'                => array(
				'id' => array(
					'type'     => 'integer',
					'minimum'  => 1,
					'required' => true,
				),
			),
		)
	);

	register_rest_route(
		'consulta-pedidos/v1',
		'/pedidos',
		array(
			'methods'             => 'GET',
			'callback'            => 'cp_api_pedidos',
			'permission_callback' => 'cp_permiso_token',
			'args'                => array(
				'pagina'     => array(
					'type'    => 'integer',
					'minimum' => 1,
					'default' => 1,
				),
				'por_pagina' => array(
					'type'    => 'integer',
					'minimum' => 1,
					'maximum' => CP_MAX_POR_PAGINA,
					'default' => 10,
				),
				'orden'      => array(
					'type'    => 'string',
					'enum'    => array_keys( CP_COLUMNAS_ORDEN ),
					'default' => 'fecha',
				),
				'direccion'  => array(
					'type'    => 'string',
					'enum'    => array( 'asc', 'desc' ),
					'default' => 'desc',
				),
			),
		)
	);
}

function cp_permiso_token( WP_REST_Request $request ) {
	$usuario = cp_usuario_token( $request );
	return is_wp_error( $usuario ) ? $usuario : true;
}

function cp_api_token( WP_REST_Request $request ) {
	$usuario = sanitize_user( $request['usuario'] );
	$ip      = isset( $_SERVER['REMOTE_ADDR'] ) ? sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) ) : '';
	$llave   = 'cp_intentos_' . md5( $usuario . '|' . $ip );

	$intentos = (int) get_transient( $llave );
	if ( $intentos >= CP_MAX_INTENTOS ) {
		return new WP_Error( 'cp_bloqueado', 'Demasiados intentos. Intenta más tarde.', array( 'status' => 429 ) );
	}

	$resultado = wp_authenticate( $usuario, $request['clave'] );
	if ( is_wp_error( $resultado ) ) {
		set_transient( $llave, $intentos + 1, CP_BLOQUEO );
		// Mismo mensaje si falla el usuario o la contraseña, para no revelar cuentas existentes.
		return new WP_Error( 'cp_login', 'Usuario o contraseña incorrectos.', array( 'status' => 401 ) );
	}
	delete_transient( $llave );

	$token = cp_emitir_token( $resultado );
	if ( is_wp_error( $token ) ) {
		return $token;
	}
	return array(
		'token'     => $token,
		'expira_en' => CP_JWT_DURACION,
	);
}

function cp_api_pedido( WP_REST_Request $request ) {
	$usuario = cp_usuario_token( $request );
	$pedido  = cp_obtener_pedido( $request['id'] );

	// Se responde igual si el pedido no existe o es de otro cliente, para no revelar qué pedidos existen.
	if ( ! cp_puede_ver( $usuario, $pedido ) ) {
		return new WP_Error( 'cp_no_existe', 'El pedido no existe.', array( 'status' => 404 ) );
	}
	return cp_vista_pedido( $usuario, $pedido );
}

function cp_api_pedidos( WP_REST_Request $request ) {
	$usuario    = cp_usuario_token( $request );
	$cliente_id = cp_es_gestor( $usuario ) ? 0 : $usuario->ID;

	$pedidos = cp_listar_pedidos(
		$cliente_id,
		$request['pagina'],
		$request['por_pagina'],
		$request['orden'],
		$request['direccion']
	);
	return array_map(
		function ( $pedido ) use ( $usuario ) {
			return cp_vista_pedido( $usuario, $pedido );
		},
		$pedidos
	);
}

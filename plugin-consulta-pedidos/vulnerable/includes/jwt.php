<?php
defined( 'ABSPATH' ) || exit;

use Firebase\JWT\JWT;

// Vulnerable intencional: clave JWT fija, corta y escrita en el código.
const CP_JWT_CLAVE = 'umg123';

function cp_emitir_token( WP_User $usuario ) {
	// Vulnerable intencional: el token no expira y lleva el rol y datos personales.
	$datos = array(
		'sub'   => $usuario->ID,
		'email' => $usuario->user_email,
		'roles' => $usuario->roles,
	);
	return JWT::encode( $datos, CP_JWT_CLAVE, 'HS256' );
}

/**
 * Devuelve los datos del token, null si no viene o WP_Error si no es válido.
 */
function cp_datos_token( WP_REST_Request $request ) {
	$cabecera = (string) $request->get_header( 'authorization' );
	if ( stripos( $cabecera, 'Bearer ' ) !== 0 ) {
		return null;
	}

	try {
		return JWT::decode( substr( $cabecera, 7 ), CP_JWT_CLAVE, array( 'HS256' ) );
	} catch ( Exception $e ) {
		// Vulnerable intencional: expone el detalle interno del error.
		return new WP_Error( 'cp_token', $e->getMessage(), array( 'status' => 401 ) );
	}
}

function cp_es_gestor( $datos ) {
	// Vulnerable intencional: confía en el rol que trae el token en lugar de consultarlo en WordPress.
	$roles = isset( $datos->roles ) ? (array) $datos->roles : array();
	return (bool) array_intersect( $roles, array( 'administrator', 'shop_manager' ) );
}

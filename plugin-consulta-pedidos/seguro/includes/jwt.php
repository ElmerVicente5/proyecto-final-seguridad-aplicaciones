<?php
defined( 'ABSPATH' ) || exit;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

const CP_JWT_AUDIENCIA = 'consulta-pedidos';
const CP_JWT_DURACION  = 900;

function cp_clave_jwt() {
	// La clave se lee de un Docker secret si está montado, o de la variable de entorno.
	$archivo = (string) getenv( 'CONSULTA_PEDIDOS_JWT_SECRET_FILE' );
	$clave   = $archivo && is_readable( $archivo ) ? trim( (string) file_get_contents( $archivo ) ) : (string) getenv( 'CONSULTA_PEDIDOS_JWT_SECRET' );
	// Una clave corta se puede adivinar por fuerza bruta a partir de un token capturado.
	return strlen( $clave ) >= 32 ? $clave : null;
}

function cp_emitir_token( WP_User $usuario ) {
	$clave = cp_clave_jwt();
	if ( ! $clave ) {
		return new WP_Error( 'cp_config', 'El servicio no está disponible.', array( 'status' => 503 ) );
	}

	$ahora = time();
	$datos = array(
		'iss' => home_url(),
		'aud' => CP_JWT_AUDIENCIA,
		'iat' => $ahora,
		'nbf' => $ahora,
		'exp' => $ahora + CP_JWT_DURACION,
		'sub' => $usuario->ID,
	);
	return JWT::encode( $datos, $clave, 'HS256' );
}

/**
 * Devuelve el usuario dueño de un token válido o WP_Error.
 */
function cp_usuario_token( WP_REST_Request $request ) {
	$invalido = new WP_Error( 'cp_token', 'Token inválido o expirado.', array( 'status' => 401 ) );

	$cabecera = (string) $request->get_header( 'authorization' );
	$clave    = cp_clave_jwt();
	if ( stripos( $cabecera, 'Bearer ' ) !== 0 || ! $clave ) {
		return $invalido;
	}

	try {
		JWT::$leeway = 30;
		// Key fija el algoritmo esperado, así no se acepta un token firmado con otro.
		$datos = JWT::decode( substr( $cabecera, 7 ), new Key( $clave, 'HS256' ) );
	} catch ( Exception $e ) {
		return $invalido;
	}

	if ( ( $datos->iss ?? '' ) !== home_url() || ( $datos->aud ?? '' ) !== CP_JWT_AUDIENCIA ) {
		return $invalido;
	}

	$usuario = get_user_by( 'id', (int) ( $datos->sub ?? 0 ) );
	return $usuario ? $usuario : $invalido;
}

function cp_es_gestor( WP_User $usuario ) {
	// El permiso se consulta en WordPress, no se toma del contenido del token.
	return user_can( $usuario, 'manage_woocommerce' );
}

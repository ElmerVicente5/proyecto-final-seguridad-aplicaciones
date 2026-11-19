<?php
/**
 * Plugin Name: UMG Hardening
 * Description: Endurecimiento de WordPress para la fase 5: cabeceras de seguridad y freno a la enumeracion de usuarios.
 *
 * Es un must-use plugin: se carga siempre y no se puede desactivar desde el panel.
 */

defined( 'ABSPATH' ) || exit;

// Cabeceras de seguridad que faltaban en la linea base (detectadas por ZAP y Postman en la fase 3).
add_filter(
	'wp_headers',
	function ( $headers ) {
		$headers['X-Frame-Options']        = 'SAMEORIGIN';
		$headers['X-Content-Type-Options'] = 'nosniff';
		$headers['Referrer-Policy']        = 'strict-origin-when-cross-origin';
		$headers['Content-Security-Policy'] = "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'";
		return $headers;
	}
);

// No anunciar la version de WordPress ni la de PHP.
remove_action( 'wp_head', 'wp_generator' );
add_filter( 'the_generator', '__return_empty_string' );
if ( ! headers_sent() ) {
	header_remove( 'X-Powered-By' );
}

// Cerrar la enumeracion de usuarios por la API REST a quien no haya iniciado sesion.
add_filter(
	'rest_endpoints',
	function ( $endpoints ) {
		foreach ( array( '/wp/v2/users', '/wp/v2/users/(?P<id>[\d]+)' ) as $ruta ) {
			if ( isset( $endpoints[ $ruta ] ) ) {
				foreach ( $endpoints[ $ruta ] as $i => $controlador ) {
					if ( isset( $controlador['methods'] ) && false !== strpos( $controlador['methods'], 'GET' ) ) {
						$endpoints[ $ruta ][ $i ]['permission_callback'] = function () {
							return is_user_logged_in();
						};
					}
				}
			}
		}
		return $endpoints;
	}
);

// Quitar el enlace oembed que tambien revela el autor.
remove_action( 'wp_head', 'wp_oembed_add_discovery_links' );

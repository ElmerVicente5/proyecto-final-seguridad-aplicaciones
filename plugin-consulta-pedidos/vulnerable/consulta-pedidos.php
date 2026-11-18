<?php
/**
 * Plugin Name: Consulta de Pedidos UMG
 * Description: Consulta de pedidos de WooCommerce por API REST y shortcode. Versión vulnerable del laboratorio.
 * Version: 1.0.0
 * Requires PHP: 8.1
 * Text Domain: consulta-pedidos
 */

defined( 'ABSPATH' ) || exit;

if ( ! file_exists( __DIR__ . '/vendor/autoload.php' ) ) {
	add_action(
		'admin_notices',
		function () {
			echo '<div class="notice notice-error"><p>Consulta de Pedidos: falta ejecutar composer install.</p></div>';
		}
	);
	return;
}

require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/includes/jwt.php';
require_once __DIR__ . '/includes/consultas.php';
require_once __DIR__ . '/includes/api.php';
require_once __DIR__ . '/includes/shortcode.php';

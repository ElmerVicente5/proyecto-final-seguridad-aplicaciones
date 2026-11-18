<?php
defined( 'ABSPATH' ) || exit;

function cp_sql_base() {
	global $wpdb;
	// Los datos del pedido están en postmeta, así que se pivotean a columnas.
	return "SELECT p.ID AS id, p.post_status AS estado, p.post_date AS fecha,
			MAX(CASE WHEN m.meta_key = '_customer_user' THEN m.meta_value END) AS cliente_id,
			MAX(CASE WHEN m.meta_key = '_billing_first_name' THEN m.meta_value END) AS nombre,
			MAX(CASE WHEN m.meta_key = '_billing_last_name' THEN m.meta_value END) AS apellido,
			MAX(CASE WHEN m.meta_key = '_billing_email' THEN m.meta_value END) AS email,
			MAX(CASE WHEN m.meta_key = '_billing_phone' THEN m.meta_value END) AS telefono,
			MAX(CASE WHEN m.meta_key = '_billing_address_1' THEN m.meta_value END) AS direccion,
			MAX(CASE WHEN m.meta_key = '_order_total' THEN m.meta_value END) AS total
		FROM {$wpdb->posts} p
		LEFT JOIN {$wpdb->postmeta} m ON m.post_id = p.ID
		WHERE p.post_type = 'shop_order'";
}

function cp_obtener_pedido( $id ) {
	global $wpdb;
	// Vulnerable intencional: consulta sin preparar, el id se concatena tal cual.
	$fila = $wpdb->get_row( cp_sql_base() . " AND p.ID = $id GROUP BY p.ID", ARRAY_A );
	if ( $wpdb->last_error ) {
		// Vulnerable intencional: el error de SQL se devuelve al cliente.
		return new WP_Error( 'cp_sql', $wpdb->last_error, array( 'status' => 500 ) );
	}
	return $fila;
}

function cp_listar_pedidos( $cliente_id, $pagina, $por_pagina, $orden ) {
	global $wpdb;
	$sql = cp_sql_base() . ' GROUP BY p.ID';
	if ( $cliente_id ) {
		$sql .= " HAVING cliente_id = $cliente_id";
	}
	$desde = ( (int) $pagina - 1 ) * (int) $por_pagina;
	// Vulnerable intencional: orden y límite vienen del cliente sin validar.
	$sql .= " ORDER BY $orden LIMIT $por_pagina OFFSET $desde";

	$filas = $wpdb->get_results( $sql, ARRAY_A );
	if ( $wpdb->last_error ) {
		return new WP_Error( 'cp_sql', $wpdb->last_error, array( 'status' => 500 ) );
	}
	return $filas;
}

function cp_comentarios( $pedido_id ) {
	return get_post_meta( $pedido_id, '_cp_comentario' );
}

function cp_agregar_comentario( $pedido_id, $texto ) {
	add_post_meta( $pedido_id, '_cp_comentario', $texto );
}

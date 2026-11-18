<?php
defined( 'ABSPATH' ) || exit;

const CP_COLUMNAS_ORDEN = array(
	'fecha' => 'p.post_date',
	'total' => 'CAST(total AS DECIMAL(12,2))',
	'id'    => 'p.ID',
);

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
	return $wpdb->get_row( $wpdb->prepare( cp_sql_base() . ' AND p.ID = %d GROUP BY p.ID', $id ), ARRAY_A );
}

function cp_listar_pedidos( $cliente_id, $pagina, $por_pagina, $orden, $direccion ) {
	global $wpdb;
	$columna   = CP_COLUMNAS_ORDEN[ $orden ] ?? 'p.post_date';
	$direccion = 'asc' === strtolower( $direccion ) ? 'ASC' : 'DESC';

	$sql        = cp_sql_base() . ' GROUP BY p.ID';
	$parametros = array();
	if ( $cliente_id ) {
		$sql         .= ' HAVING cliente_id = %d';
		$parametros[] = $cliente_id;
	}
	// La columna y la dirección salen de listas blancas, por eso pueden ir directo en el SQL.
	$sql         .= " ORDER BY $columna $direccion LIMIT %d OFFSET %d";
	$parametros[] = $por_pagina;
	$parametros[] = ( $pagina - 1 ) * $por_pagina;

	return $wpdb->get_results( $wpdb->prepare( $sql, $parametros ), ARRAY_A );
}

function cp_puede_ver( WP_User $usuario, $pedido ) {
	return $pedido && ( cp_es_gestor( $usuario ) || (int) $pedido['cliente_id'] === $usuario->ID );
}

function cp_vista_pedido( WP_User $usuario, array $pedido ) {
	if ( cp_es_gestor( $usuario ) ) {
		return $pedido;
	}
	// Al cliente solo se le devuelven los campos que necesita para revisar su pedido.
	return array_intersect_key( $pedido, array_flip( array( 'id', 'estado', 'fecha', 'nombre', 'apellido', 'total' ) ) );
}

function cp_comentarios( $pedido_id ) {
	return get_post_meta( $pedido_id, '_cp_comentario' );
}

function cp_agregar_comentario( $pedido_id, $texto ) {
	// add_post_meta quita barras invertidas, así que se agregan antes para conservar el texto.
	add_post_meta( $pedido_id, '_cp_comentario', wp_slash( $texto ) );
}

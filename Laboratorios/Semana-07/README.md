# Laboratorio Integrador I — NYC Yellow Taxi

Pipeline ELT reproducible con Kestra, Snowflake y dbt para los viajes de NYC
Yellow Taxi de enero de 2025 a agosto de 2026.

## Arquitectura

```mermaid
flowchart LR
    TLC[NYC TLC Parquet] -->|HTTP Download| K[Kestra]
    K -->|Upload| STAGE[Snowflake Internal Stage]
    STAGE -->|COPY INTO| B[Bronze: datos raw + metadata]
    B -->|dbt clean and deduplicate| S[Silver: viajes estandarizados]
    S -->|dbt build and tests| G[Gold: esquema estrella]
```

## Esquema estrella

```mermaid
erDiagram
    DIM_DATE ||--o{ FCT_TRIPS : pickup_date
    DIM_DATE ||--o{ FCT_TRIPS : dropoff_date
    DIM_VENDOR ||--o{ FCT_TRIPS : vendor
    DIM_PAYMENT_TYPE ||--o{ FCT_TRIPS : payment
    DIM_RATE_CODE ||--o{ FCT_TRIPS : rate
    DIM_LOCATION ||--o{ FCT_TRIPS : pickup_location
    DIM_LOCATION ||--o{ FCT_TRIPS : dropoff_location

    FCT_TRIPS {
      string trip_key PK
      int vendor_key FK
      int payment_type_key FK
      int rate_code_key FK
      int pickup_location_key FK
      int dropoff_location_key FK
      int pickup_date_key FK
      int dropoff_date_key FK
      number trip_distance
      number total_amount
      int trip_duration_seconds
    }
```

El grano de `GOLD.FCT_TRIPS` es una fila por viaje válido y deduplicado.

## Ejecución

1. Copiar `.env.example` a `.env` y completar las credenciales.
2. Levantar la infraestructura con `docker compose up -d`.
3. Ejecutar `snowflake/setup.sql` en un Worksheet de Snowflake.
4. Confirmar que este proyecto esté publicado en la rama `main` de GitHub.
5. Abrir Kestra en `http://localhost:8080`, crear un flow y pegar el contenido
   de `kestra/nyc_yellow_taxi_elt.yaml`.
6. Guardar y ejecutar el flow. Al terminar deben existir las tablas de las
   capas `BRONZE`, `SILVER` y `GOLD` y todos los tests de dbt deben pasar.

El trigger mensual está incluido pero deshabilitado para evitar ejecuciones
involuntarias durante el desarrollo.

## Idempotencia

Cada período se reemplaza dentro de una transacción antes de volver a cargar su
Parquet. Los modelos dbt se reconstruyen con `--full-refresh`, por lo que repetir
el flow no crea duplicados.

## Decisiones de calidad en Silver

- Los campos se convierten con `TRY_TO_*` para evitar conversiones implícitas.
- Los nulos categóricos se asignan a valores conocidos de `Unknown`.
- Los viajes sin fechas o ubicaciones válidas se excluyen.
- Se excluyen duraciones negativas, distancias negativas y totales negativos.
- Los duplicados exactos se eliminan mediante una llave hash estable.
- Se conserva `source_file`, `source_period` y `loaded_at` para trazabilidad.

## Disponibilidad de agosto de 2026

Al 28 de septiembre de 2026, TLC publica archivos hasta julio de 2026. La URL
de agosto todavía responde `403`. Cuando esté disponible, agregar `"2026-08"`
al input `periods` del flow y volver a ejecutarlo.

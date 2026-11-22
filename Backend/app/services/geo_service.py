from collections.abc import Mapping, Sequence
from typing import Any

from geoalchemy2.shape import from_shape, to_shape
from shapely.geometry import LineString

from app.db.schemas.ride import GeoPoint


# ─────────────────────────────────────────────────────────────────────────────
# Internal Types
# ─────────────────────────────────────────────────────────────────────────────

GeometryPointInput = GeoPoint | Mapping[str, float]


# ─────────────────────────────────────────────────────────────────────────────
# Point Validation
# ─────────────────────────────────────────────────────────────────────────────

def _validate_point(
    point: GeometryPointInput,
) -> tuple[float, float]:
    """
    Validate a geographic point and convert it into the coordinate order
    required by Shapely/PostGIS.

    API representation:
        latitude
        longitude

    PostGIS / Shapely representation:
        X = longitude
        Y = latitude
    """

    if isinstance(point, GeoPoint):
        lat = float(point.latitude)
        lng = float(point.longitude)

    elif isinstance(point, Mapping):
        if "latitude" not in point or "longitude" not in point:
            raise ValueError(
                "Every geometry point must contain latitude and longitude."
            )

        lat = float(point["latitude"])
        lng = float(point["longitude"])

    else:
        raise ValueError(
            "Invalid geometry point. "
            "Expected GeoPoint or latitude/longitude mapping."
        )

    if not -90.0 <= lat <= 90.0:
        raise ValueError(
            "Latitude must be between -90 and 90."
        )

    if not -180.0 <= lng <= 180.0:
        raise ValueError(
            "Longitude must be between -180 and 180."
        )

    # Shapely/PostGIS:
    # X = longitude
    # Y = latitude
    return lng, lat


# ─────────────────────────────────────────────────────────────────────────────
# API → PostGIS
# ─────────────────────────────────────────────────────────────────────────────

def line_from_api_points(
    points: Sequence[GeometryPointInput],
):
    """
    Convert API route points into a PostGIS LINESTRING.

    API:
        latitude / longitude

    PostGIS:
        longitude / latitude
    """

    if len(points) < 2:
        raise ValueError(
            "A LINESTRING requires at least two points."
        )

    coordinates = [
        _validate_point(point)
        for point in points
    ]

    line = LineString(coordinates)

    if line.is_empty:
        raise ValueError(
            "Route geometry is empty."
        )

    if not line.is_valid:
        raise ValueError(
            "Route geometry is invalid."
        )

    return from_shape(
        line,
        srid=4326,
    )


# ─────────────────────────────────────────────────────────────────────────────
# PostGIS → API
# ─────────────────────────────────────────────────────────────────────────────

def api_points_from_geometry(
    value: Any,
) -> list[GeoPoint]:
    """
    Convert a PostGIS geometry value back into API GeoPoint objects.

    PostGIS / Shapely:
        X = longitude
        Y = latitude

    API:
        latitude
        longitude
    """

    if value is None:
        return []

    shape = to_shape(value)

    if shape.is_empty:
        return []

    return [
        GeoPoint(
            latitude=float(lat),
            longitude=float(lng),
        )
        for lng, lat in shape.coords
    ]
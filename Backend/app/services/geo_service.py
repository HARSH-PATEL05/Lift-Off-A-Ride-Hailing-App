from typing import Any

from geoalchemy2.shape import from_shape, to_shape
from shapely.geometry import LineString


def _validate_point(
    point: dict[str, float],
) -> tuple[float, float]:

    if "latitude" not in point or "longitude" not in point:
        raise ValueError(
            "Every geometry point must contain latitude and longitude."
        )

    lat = float(point["latitude"])
    lng = float(point["longitude"])

    if not -90 <= lat <= 90:
        raise ValueError(
            "Latitude must be between -90 and 90."
        )

    if not -180 <= lng <= 180:
        raise ValueError(
            "Longitude must be between -180 and 180."
        )

    # Shapely/PostGIS:
    # X = longitude
    # Y = latitude
    return lng, lat


def line_from_api_points(
    points: list[dict[str, float]],
):
    """
    Convert API route points into a PostGIS LINESTRING.

    API:
        latitude, longitude

    PostGIS:
        longitude, latitude
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


def api_points_from_geometry(
    value: Any,
) -> list[dict[str, float]]:

    if value is None:
        return []

    shape = to_shape(value)

    if shape.is_empty:
        return []

    return [
        {
            "latitude": float(lat),
            "longitude": float(lng),
        }
        for lng, lat in shape.coords
    ]
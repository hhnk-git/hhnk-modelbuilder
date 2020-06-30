# -*- coding: utf-8 -*-
# (c) Nelen & Schuurmans, see LICENSE.rst.

import logging

from sqlalchemy import Boolean, Column, Integer, String, Float, ForeignKey, DateTime, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from geoalchemy2.types import Geometry

from .constants import Constants

logger = logging.getLogger(__name__)
Base = declarative_base()


def prettify(value, postfix, value_format="%0.2f"):
    """
    return prettified string of given value
    value may be None
    postfix can be used for unit for example
    """
    if value is None:
        value_str = "--"
    else:
        value_str = value_format % value
    return "%s %s" % (value_str, postfix)


class GlobalSetting(Base):
    __tablename__ = "v2_global_settings"
    # Here we define columns for the table person
    # Notice that each column is also a normal Python instance attribute.
    id = Column(Integer, primary_key=True)
    use_2d_flow =Column(Boolean)
    use_1d_flow = Column(Boolean)
    manhole_storage_area = Column(Float)
    name = Column(String(255), nullable=True)
    sim_time_step = Column(Float)
    output_time_step = Column(Float)
    nr_timesteps = Column(Float)
    
    start_time = Column(DateTime)
    start_date = Column(String(255),nullable=False)
    grid_space = Column(Float)
    dist_calc_points = Column(Float)
    kmax = Column(Integer)
    guess_dams = Column(Integer)
    table_step_size = Column(Float)
    flooding_threshold = Column(Float)
    advection_1d = Column(Integer)
    advection_2d = Column(Integer)
    
    dem_file = Column(String(255), nullable=True)
    frict_type = Column(Integer)
    frict_coef = Column(Float)
    frict_coef_file = Column(String(255), nullable=True)
    water_level_ini_type = Column(Integer)
    initial_waterlevel = Column(Float)
    initial_waterlevel_file = Column(String(255), nullable=True)
    interception_global = Column(Float)
    interception_file = Column(String(255), nullable = True)
    
    dem_obstacle_detection = Column(Boolean)
    dem_obstacle_height = Column(Float)
    embedded_cutoff_threshold = Column(Float)
    epsg_code = Column(Integer)
    timestep_plus = Column(Boolean)
    max_angle_1d_advection = Column(Float)
    minimum_sim_time_step = Column(Float)
    frict_avg = Column(Integer)
    wind_shielding_file = Column(String(255), nullable = True)
    
    control_group_id = Column(Integer)
    numerical_settings_id = Column(Integer)
    use_0d_inflow = Column(Integer)
    table_step_size_1d = Column(Float)
    table_step_size_volume_2d = Column(Float)
    use_2d_rain = Column(Integer)
    initial_groundwater_level = Column(Float)
    initial_groundwater_level_file = Column(String(255), nullable = True)
    initial_groundwater_level_type = Column(Integer)
    groundwater_settings_id = Column(Integer)
    simple_infiltration_settings_id = Column(Integer)
    interflow_settings_id = Column(Integer)
    
    kmax = Column(Integer)


    def __str__(self):
        return u"Global setting [dem_file=%s, frict_coef_file=%s]" % (
            self.dem_file,
            self.frict_coef_file,
        )


class CrossSectionDefinition(Base):
    __tablename__ = "v2_cross_section_definition"

    PROFILE_SHAPES = Constants.PROFILE_SHAPES

    id = Column(Integer, primary_key=True)
    width = Column(Float)
    height = Column(Float)
    shape = Column(Integer)  # PROFILE_SHAPES
    code = Column(String(100), default="", nullable=False)


class ConnectionNode(Base):
    __tablename__ = "v2_connection_nodes"

    # why does connection node not has a code and zoom_category???

    id = Column(Integer, primary_key=True)
    storage_area = Column(Float)
    initial_waterlevel = Column(Float)
    the_geom = Column(
        Geometry(geometry_type="POINT", srid=4326, spatial_index=True), nullable=False
    )

    the_geom_linestring = Column(
        Geometry(geometry_type="POINT", srid=4326, spatial_index=False), nullable=True
    )

    # extra fields:
    code = Column(String(100), default="", nullable=True)

    manhole = relationship("Manhole", uselist=False, back_populates="connection_node")
    boundary_condition = relationship(
        "BoundaryCondition1D", uselist=False, back_populates="connection_node"
    )
    impervious_surface_map = relationship(
        "ImperviousSurfaceMap", back_populates="connection_node"
    )
    
    surface_map = relationship(
        "SurfaceMap", back_populates="connection_node"
    )
    
    lateral_1d = relationship(
        "Lateral1D", back_populates="connection_node"
    )


#    onedee_lateral = relationship("OnedeeLateral")


class Manhole(Base):
    __tablename__ = "v2_manhole"

    MANHOLE_INDICATORS = Constants.MANHOLE_INDICATORS
    CALCULATION_TYPES = Constants.CALCULATION_TYPES
    MANHOLE_SHAPES = Constants.MANHOLE_SHAPES

    id = Column(Integer, primary_key=True)
    code = Column(String(100), nullable=False)
    display_name = Column(String(255), nullable=False, default="")
    zoom_category = Column(Integer)

    width = Column(Float)
    shape = Column(String(4))  # MANHOLE_SHAPES
    length = Column(Float)
    surface_level = Column(Float)
    bottom_level = Column(Float)
    drain_level = Column(Float)
    sediment_level = Column(Float)
    manhole_indicator = Column(Integer)  # MANHOLE_INDICATORS
    calculation_type = Column(Integer)  # CALCULATION_TYPES

    connection_node_id = Column(
        Integer,
        ForeignKey(ConnectionNode.__tablename__ + ".id"),
        nullable=False,
        unique=True,
    )
    connection_node = relationship(ConnectionNode, back_populates="manhole")


class BoundaryCondition1D(Base):
    """
    TODO: more fields
    """

    __tablename__ = "v2_1d_boundary_conditions"

    BOUNDARY_TYPES = Constants.BOUNDARY_TYPES

    id = Column(Integer, primary_key=True)
    boundary_type = Column(Integer)
    timeseries = Column(String)

    connection_node_id = Column(
        Integer,
        ForeignKey(ConnectionNode.__tablename__ + ".id"),
        nullable=False,
        unique=True,
    )
    connection_node = relationship(
        ConnectionNode,
        foreign_keys=connection_node_id,
        back_populates="boundary_condition",
    )


class Channel(Base):

    __tablename__ = "v2_channel"

    CALCULATION_TYPES = Constants.CALCULATION_TYPES

    id = Column(Integer, primary_key=True)
    code = Column(String(100), nullable=False)
    display_name = Column(String(255), nullable=False, default="")
    zoom_category = Column(Integer, nullable=True)  # default=2

    calculation_type = Column(Integer, nullable=True)
    dist_calc_points = Column(Float, nullable=True)
    the_geom = Column(
        Geometry(geometry_type="LINESTRING", srid=4326, spatial_index=True),
        nullable=False,
    )

    # node relations
    connection_node_start_id = Column(
        ForeignKey(ConnectionNode.__tablename__ + ".id"), nullable=True
    )
    connection_node_start = relationship(
        ConnectionNode, foreign_keys=connection_node_start_id
    )

    connection_node_end_id = Column(
        ForeignKey(ConnectionNode.__tablename__ + ".id"), nullable=True
    )
    connection_node_end = relationship(
        ConnectionNode, foreign_keys=connection_node_end_id
    )

    cross_section_locations = relationship(
        "CrossSectionLocation", back_populates="channel"
    )
    
    windshielding = relationship(
        "Windshielding", back_populates="channel"
    )


class CrossSectionLocation(Base):
    __tablename__ = "v2_cross_section_location"

    FRICTION_TYPE = Constants.FRICTION_TYPES

    id = Column(Integer, primary_key=True)
    code = Column(String(100), default="", nullable=False)
    channel_id = Column(Integer, ForeignKey("v2_channel.id"), nullable=False)
    channel = relationship(Channel, back_populates="cross_section_locations")

    definition_id = Column(
        Integer, ForeignKey("v2_cross_section_definition.id"), nullable=True
    )
    definition = relationship(CrossSectionDefinition)

    reference_level = Column(Float)
    friction_type = Column(Integer)  # FRICTION_TYPES
    friction_value = Column(Float)
    bank_level = Column(Float)
    the_geom = Column(
        Geometry(geometry_type="POINT", srid=4326, spatial_index=True), nullable=False
    )


class Pipe(Base):

    __tablename__ = "v2_pipe"

    CALCULATION_TYPES = Constants.CALCULATION_TYPES
    SEWERAGE_TYPES = Constants.SEWERAGE_TYPES
    MATERIALS = Constants.MATERIALS

    id = Column(Integer, primary_key=True)
    code = Column(String(100), nullable=False)
    display_name = Column(String(255), nullable=False, default="")
    zoom_category = Column(Integer, nullable=True, default=2)

    # node relations
    connection_node_start_id = Column(
        ForeignKey(ConnectionNode.__tablename__ + ".id"), nullable=True
    )
    connection_node_start = relationship(
        ConnectionNode, foreign_keys=connection_node_start_id
    )

    connection_node_end_id = Column(
        ForeignKey(ConnectionNode.__tablename__ + ".id"), nullable=True
    )
    connection_node_end = relationship(
        ConnectionNode, foreign_keys=connection_node_end_id
    )

    original_length = Column(Float)

    # cross section and level
    cross_section_definition_id = Column(
        Integer, ForeignKey("v2_cross_section_definition.id"), nullable=True
    )
    cross_section_definition = relationship("CrossSectionDefinition")

    invert_level_start_point = Column(Float)
    invert_level_end_point = Column(Float)

    # friction
    friction_value = Column(Float)
    friction_type = Column(Integer)  # FRICTION_TYPE

    profile_num = Column(Integer)  # ??
    sewerage_type = Column(Integer)  # SEWERAGE_TYPES
    calculation_type = Column(Integer)  # CALCULATION_TYPES
    dist_calc_points = Column(Float)

    material = Column(Integer)  # MATERIALS


class Culvert(Base):
    # todo: check this definition with original
    __tablename__ = "v2_culvert"

    CALCULATION_TYPES = Constants.CALCULATION_TYPES

    id = Column(Integer, primary_key=True)
    code = Column(String(100), nullable=False)
    display_name = Column(String(255), nullable=False)
    zoom_category = Column(Integer, nullable=True)  # default=2

    # node relations
    connection_node_start_id = Column(
        "connection_node_start_id",
        ForeignKey(ConnectionNode.__tablename__ + ".id"),
        nullable=False,
    )
    connection_node_start = relationship(
        ConnectionNode, foreign_keys=connection_node_start_id
    )

    connection_node_end_id = Column(
        "connection_node_end_id",
        ForeignKey(ConnectionNode.__tablename__ + ".id"),
        nullable=False,
    )
    connection_node_end = relationship(
        ConnectionNode, foreign_keys=connection_node_end_id
    )

    # cross section and level
    cross_section_definition_id = Column(
        Integer, ForeignKey("v2_cross_section_definition.id"), nullable=True
    )
    cross_section_definition = relationship(CrossSectionDefinition)
    invert_level_start_point = Column(Float)
    invert_level_end_point = Column(Float)

    # friction and flow direction
    friction_value = Column(Float)
    friction_type = Column(Integer)
    discharge_coefficient_positive = Column(Float)
    discharge_coefficient_negative = Column(Float)

    # other attributes
    calculation_type = Column(Integer)
    dist_calc_points = Column(Float, nullable=True)

    the_geom = Column(
        Geometry(geometry_type="LINESTRING", srid=4326, spatial_index=True),
        nullable=True,
    )


class Weir(Base):

    __tablename__ = "v2_weir"

    CREST_TYPES = Constants.CREST_TYPES
    FRICTION_TYPES = Constants.FRICTION_TYPES

    id = Column(Integer, primary_key=True)
    code = Column(String(100), nullable=False)
    display_name = Column(String(255), nullable=False, default="")
    zoom_category = Column(Integer, nullable=True, default=2)

    # node relations
    connection_node_start_id = Column(
        "connection_node_start_id",
        ForeignKey(ConnectionNode.__tablename__ + ".id"),
        nullable=True,
    )
    connection_node_start = relationship(
        ConnectionNode, foreign_keys=connection_node_start_id
    )

    connection_node_end_id = Column(
        "connection_node_end_id",
        ForeignKey(ConnectionNode.__tablename__ + ".id"),
        nullable=True,
    )
    connection_node_end = relationship(
        ConnectionNode, foreign_keys=connection_node_end_id
    )

    # crest level and cross section
    crest_type = Column(Integer)  # CREST_TYPE
    crest_level = Column(Float)

    cross_section_definition_id = Column(
        Integer, ForeignKey("v2_cross_section_definition.id"), nullable=True
    )
    cross_section_definition = relationship("CrossSectionDefinition")

    # friction and flow direction
    friction_value = Column(Float)
    friction_type = Column(Integer)  # FRICTION_TYPES
    discharge_coefficient_positive = Column(Float)
    discharge_coefficient_negative = Column(Float)

    sewerage = Column(Boolean)
    external = Column(Boolean)


class Orifice(Base):

    __tablename__ = "v2_orifice"

    CREST_TYPES = Constants.CREST_TYPES
    FRICTION_TYPES = Constants.FRICTION_TYPES

    id = Column(Integer, primary_key=True)
    code = Column(String(100), nullable=False)
    display_name = Column(String(255), nullable=False, default="")
    zoom_category = Column(Integer, nullable=True)  # default=2

    # node relations
    connection_node_start_id = Column(
        "connection_node_start_id",
        ForeignKey(ConnectionNode.__tablename__ + ".id"),
        nullable=True,
    )
    connection_node_start = relationship(
        ConnectionNode, foreign_keys=connection_node_start_id
    )

    connection_node_end_id = Column(
        "connection_node_end_id",
        ForeignKey(ConnectionNode.__tablename__ + ".id"),
        nullable=True,
    )
    connection_node_end = relationship(
        ConnectionNode, foreign_keys=connection_node_end_id
    )

    # crest and cross section
    crest_type = Column(Integer)  # CREST_TYPES
    crest_level = Column(Float)

    cross_section_definition_id = Column(
        Integer, ForeignKey("v2_cross_section_definition.id"), nullable=True
    )
    cross_section_definition = relationship("CrossSectionDefinition")

    # friction and flow direction
    friction_value = Column(Float)
    friction_type = Column(Integer)  # FRICTION_TYPES
    discharge_coefficient_positive = Column(Float)
    discharge_coefficient_negative = Column(Float)

    sewerage = Column(Boolean, default=False)
    max_capacity = Column(Float)

    @property
    def max_capacity_str(self):
        if self.max_capacity is None:
            max_capacity_rep = "-- [m3/s]"
        else:
            max_capacity_rep = "%0.1f [m3/s]" % self.max_capacity
        return max_capacity_rep


class Pumpstation(Base):

    __tablename__ = "v2_pumpstation"

    id = Column(Integer, primary_key=True)
    code = Column(String(100), nullable=False)
    display_name = Column(String(255), nullable=False, default="")
    zoom_category = Column(Integer, nullable=True)

    sewerage = Column(Boolean, default=False)
    classification = Column(Integer)  # in use?
    type_ = Column(Integer, nullable=True, default=1, name="type")

    # relation ships
    connection_node_start_id = Column(
        "connection_node_start_id",
        ForeignKey(ConnectionNode.__tablename__ + ".id"),
        nullable=True,
    )
    connection_node_start = relationship(
        ConnectionNode, foreign_keys=connection_node_start_id
    )

    connection_node_end_id = Column(
        "connection_node_end_id",
        ForeignKey(ConnectionNode.__tablename__ + ".id"),
        nullable=True,
    )
    connection_node_end = relationship(
        ConnectionNode, foreign_keys=connection_node_end_id
    )

    # pump details
    start_level = Column(Float)
    lower_stop_level = Column(Float)
    upper_stop_level = Column(Float)
    capacity = Column(Float)


class Obstacle(Base):
    __tablename__ = "v2_obstacle"

    id = Column(Integer, primary_key=True)
    code = Column(String(100), default="", nullable=False)

    crest_level = Column(Float)
    the_geom = Column(
        Geometry(geometry_type="LINESTRING", srid=4326, spatial_index=True),
        nullable=True,
    )


class Levee(Base):
    __tablename__ = "v2_levee"

    LEVEE_MATERIALS = Constants.LEVEE_MATERIALS

    id = Column(Integer, primary_key=True)
    code = Column(String(100), default="", nullable=False)

    crest_level = Column(Float)
    the_geom = Column(
        Geometry(geometry_type="LINESTRING", srid=4326, spatial_index=True),
        nullable=True,
    )

    material = Column(Integer)
    max_breach_depth = Column(Float)


class ImperviousSurface(Base):

    __tablename__ = "v2_impervious_surface"

    id = Column(Integer, primary_key=True)

    code = Column(String(100), nullable=False)
    display_name = Column(String(255), nullable=False, default="")

    surface_inclination = Column(String(64), nullable=False)
    surface_class = Column(String(128), nullable=False)
    surface_sub_class = Column(String(128), nullable=True)
    function_ = Column(String(64), name="function", nullable=True)

    zoom_category = Column(Integer)
    nr_of_inhabitants = Column(Float)
    area = Column(Float)
    dry_weather_flow = Column(Float)

    the_geom = Column(
        Geometry(geometry_type="POLYGON", srid=4326, spatial_index=True), nullable=True
    )

    impervious_surface_maps = relationship(
        "ImperviousSurfaceMap", back_populates="impervious_surface"
    )

class ImperviousSurfaceMap(Base):
    __tablename__ = "v2_impervious_surface_map"

    id = Column(Integer, primary_key=True)

    impervious_surface_id = Column(
        Integer, ForeignKey(ImperviousSurface.__tablename__ + ".id"), nullable=True
    )
    impervious_surface = relationship(
        ImperviousSurface, back_populates="impervious_surface_maps"
    )

    connection_node_id = Column(
        Integer, ForeignKey(ConnectionNode.__tablename__ + ".id"), nullable=False
    )
    connection_node = relationship(
        ConnectionNode, back_populates="impervious_surface_map"
    )

    percentage = Column(Float)

class SurfaceParameters(Base):
    __tablename__ = "v2_surface_parameters"
    
    id = Column(Integer, primary_key=True)
    surface = relationship(
        "Surface", back_populates="surface_parameters"
    )
    outflow_delay = Column(Float)
    surface_layer_thickness = Column(Float)
    infiltration = Column(Boolean)
    max_infiltration_capacity = Column(Float)
    min_infiltration_capacity = Column(Float)
    infiltration_decay_constant = Column(Float)
    infiltration_recovery_constant = Column(Float)  
    
class Surface(Base):

    __tablename__ = "v2_surface"

    id = Column(Integer, primary_key=True)

    code = Column(String(100), nullable=False)
    display_name = Column(String(255), nullable=False, default="")

    function_ = Column(String(64), name="function", nullable=True)

    zoom_category = Column(Integer)
    nr_of_inhabitants = Column(Float)
    area = Column(Float)
    dry_weather_flow = Column(Float)
    surface_parameters_id = Column(Integer, ForeignKey(SurfaceParameters.__tablename__ + ".id"), nullable=True
    )

    the_geom = Column(
        Geometry(geometry_type="POLYGON", srid=4326, spatial_index=True), nullable=True
    )

    surface_parameters = relationship(
        "SurfaceParameters", back_populates="surface"
        )
    
    surface_maps = relationship(
        "SurfaceMap", back_populates="surface"
    )
    
class SurfaceMap(Base):
    __tablename__ = "v2_surface_map"

    id = Column(Integer, primary_key=True)

    surface_type = Column(Integer, nullable=False)
    surface_id = Column(
        Integer, ForeignKey(Surface.__tablename__ + ".id"), nullable=True
    )
    surface = relationship(
        Surface, back_populates="surface_maps"
    )

    connection_node_id = Column(
        Integer, ForeignKey(ConnectionNode.__tablename__ + ".id"), nullable=False
    )
    connection_node = relationship(
        ConnectionNode, back_populates="surface_map"
    )

    percentage = Column(Float)
  

class GridRefinementArea(Base):
    __tablename__ = "v2_grid_refinement_area"
    
    id = Column(Integer, primary_key=True)
    
    display_name = Column(String(255), nullable=False, default="")
    refinement_level = Column(Integer, nullable=False)
    code = Column(String(255), nullable=False, default="")

    the_geom = Column(
        Geometry(geometry_type="POLYGON", srid=4326, spatial_index=True), nullable=False
    )

class GridRefinement(Base):
    __tablename__ = "v2_grid_refinement"
    
    id = Column(Integer, primary_key=True)
    
    display_name = Column(String(255), nullable=False, default="")
    refinement_level = Column(Integer, nullable=False)
    code = Column(String(255), nullable=False, default="")

    the_geom = Column(
        Geometry(geometry_type="LINESTRING", srid=4326, spatial_index=True), nullable=False
    )    

class NumericalSettings(Base):
    __tablename__ = "v2_numerical_settings"
    
    id = Column(Integer, primary_key=True)
    cfl_strictness_factor_1d = Column(Float)
    cfl_strictness_factor_2d = Column(Float)
    convergence_cg = Column(Float)
    convergence_eps = Column(Float)
    flow_direction_threshold = Column(Float)
    
    frict_shallow_water_correction = Column(Integer)
    general_numerical_threshold = Column(Float)
    integration_method = Column(Float)
    limiter_grad_1d = Column(Integer)
    limiter_grad_2d = Column(Integer)
    limiter_slope_crossectional_area_2d=Column(Integer)
    
    limiter_slope_friction_2d = Column(Integer)
    max_nonlin_iterations = Column(Integer)
    max_degree = Column(Integer)
    
    minimum_friction_velocity = Column(Float)
    minimum_surface_area = Column(Float)
    precon_cg = Column(Integer)
    preissmann_slot = Column(Float)
    pump_implicit_ratio = Column(Float)
    thin_water_layer_definition = Column(Float)
    use_of_cg = Column(Integer)
    use_of_nested_newton = Column(Integer)
    
class DemAverageArea(Base):
    __tablename__ = "v2_dem_average_area"
    
    id = Column(Integer, primary_key=True)
    the_geom = Column(
        Geometry(geometry_type="POLYGON", srid=4326, spatial_index=True), nullable=False
    )
    
class Windshielding(Base):
    __tablename__ = "v2_windshielding"
    
    id = Column(Integer, primary_key=True)
    channel_id = Column(Integer, ForeignKey(Channel.__tablename__ + ".id"), nullable=False
    )
    channel = relationship(
        Channel, back_populates="windshielding"
    )
    north = Column(Float)
    northeast = Column(Float)
    east = Column(Float)
    southeast = Column(Float)
    south = Column(Float)
    southwest = Column(Float)
    west = Column(Float)
    northwest = Column(Float)
    the_geom = Column(
        Geometry(geometry_type="POINT", srid=4326, spatial_index=True), nullable=False
    ) 

class Lateral2D(Base):
    __tablename__ = "v2_2d_lateral"
    
    id = Column(Integer, primary_key=True)
    type = Column(Integer)
    the_geom = Column(
        Geometry(geometry_type="POINT", srid=4326, spatial_index=True), nullable=False
    ) 
    timeseries = Column(String(255), nullable=False, default="")
    
class Lateral1D(Base):
    __tablename__ = "v2_1d_lateral"
    
    id = Column(Integer, primary_key=True)
    connection_node_id = Column(
        Integer, ForeignKey(ConnectionNode.__tablename__ + ".id"), nullable=False
    )
    connection_node = relationship(
        ConnectionNode, back_populates="lateral_1d"
    )
    timeseries = Column(String(255), nullable=False, default="")
    
class BoundaryCondition2D(Base):
    __tablename__ = "v2_2d_boundary_conditions"
    
    id = Column(Integer, primary_key=True)
    display_name = Column(String(255), nullable=False, default="")
    timeseries = Column(String(255), nullable=False, default="")
    boundary_type = Column(Integer)
    the_geom = Column(
        Geometry(geometry_type="LINESTRING", srid=4326, spatial_index=True), nullable=False
    )
    
class Groundwater(Base):
    __tablename__ = "v2_groundwater"
    
    id = Column(Integer, primary_key=True)
    
    groundwater_impervious_layer_level = Column(Float)
    groundwater_impervious_layer_level_file = Column(String(255), nullable=False, default="")
    groundwater_impervious_layer_level_type = Column(Integer)
    
    phreatic_storage_capacity = Column(Float)
    phreatic_storage_capacity_file = Column(String(255), nullable=False, default="")
    phreatic_storage_capacity_type = Column(Integer)
    
    equilibrium_infiltration_rate = Column(Float)
    equilibrium_infiltration_rate_file = Column(String(255), nullable=False, default="")
    equilibrium_infiltration_rate_type = Column(Integer)
    
    initial_infiltration_rate = Column(Float)
    initial_infiltration_rate_file = Column(String(255), nullable=False, default="")
    initial_infiltration_rate_type = Column(Integer)
    
    infiltration_decay_period = Column(Float)
    infiltration_decay_period_file = Column(String(255), nullable=False, default="")
    infiltration_decay_period_type = Column(Integer)
    
    groundwater_hydro_connectivity = Column(Float)
    groundwater_hydro_connectivity_file = Column(String(255), nullable=False, default="")
    groundwater_hydro_connectivity_type = Column(Integer)
    
    display_name = Column(String(255), nullable=False, default="")
    leakage = Column(Float)
    leakage_file = Column(String(255), nullable=False, default="")
    
class Interflow(Base):
    __tablename__ = "v2_interflow"
    
    id = Column(Integer, primary_key=True)
    interflow_type = Column(Integer)
    porosity = Column(Float)
    porosity_file = Column(String(255), nullable=False, default="")
    porosity_layer_thickness = Column(Float)
    
    impervious_layer_elevation = Column(Float)
    hydraulic_conductivity = Column(Float)
    hydraulic_conductivity_file = Column(String(255), nullable=False, default="")
    display_name = Column(String(255), nullable=False, default="")
    
class AggregationSettings(Base):
    __tablename__ = "v2_aggregation_settings"
    
    id = Column(Integer, primary_key=True)
    global_settings_id = Column(Integer)
    var_name = Column(String(100), nullable=False, default="")
    flow_variable = Column(String(100), nullable=False, default="")
    aggregation_method = Column(String(100), nullable=False, default="")
    aggregation_in_space = Column(Boolean)
    timestep = Column(Integer)
    
class SimpleInfiltration(Base):
    __tablename__ = "v2_simple_infiltration"
    
    id = Column(Integer, primary_key=True)
    infiltration_rate = Column(Float)
    infiltration_rate_file = Column(String(255), nullable=False, default="")
    infiltration_surface_option = Column(Integer)
    max_infiltration_capacity_file = Column(String(255), nullable=False, default="")
    display_name = Column(String(255), nullable=False, default="")
    
# TODO: add, floodfill, v2 pumpeddrainagearea control

class ControlGroup(Base):
    __tablename__ = "v2_control_group"
    
    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False, default="")
    description = Column(Text, nullable=False, default="")

class ControlMeasureGroup(Base):
    __tablename__ = "v2_control_measure_group"
    
    id = Column(Integer, primary_key=True)

class ControlMeasureMap(Base):
    __tablename__ = "v2_control_measure_map"
    
    id = Column(Integer, primary_key=True)
    measure_group_id = Column(Integer, ForeignKey(ControlMeasureGroup.__tablename__ + ".id"), nullable=False)
    object_type = Column(String(100), nullable=False, default="")
    object_id = Column(Integer)
    weight = Column(Float)

class Control(Base):
    __tablename__ = "v2_control"
    
    id = Column(Integer, primary_key=True)
    control_group_id = Column(Integer, ForeignKey(ControlGroup.__tablename__ + ".id"), nullable=False)
    control_type = Column(String(15), nullable=False, default="")
    control_id = Column(Integer)
    measure_group_id = Column(Integer, ForeignKey(ControlMeasureGroup.__tablename__ + ".id"), nullable=False)
    start = Column(String(50))
    end = Column(String(50))
    measure_frequency = Column(Integer)
    
class ControlTable(Base):
    __tablename__ = "v2_control_table"
    
    id = Column(Integer, primary_key = True)
    action_type = Column(String(50), nullable = False)
    measure_variable = Column(String(50), nullable = False)
    target_type = Column(String(100), nullable = False)
    target_id = Column(Integer)
    measure_operator = Column(String(2), nullable = False)
    action_table = Column(Text)
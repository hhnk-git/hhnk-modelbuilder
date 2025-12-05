# %%
import argparse
import configparser
import os
import shutil

import psycopg2
from osgeo import ogr, osr
from sqlalchemy.orm import load_only
from sqlalchemy.sql import text
from utils.constants import Constants
from utils.model_schematisation import (
    AggregationSettings,
    BoundaryCondition1D,
    BoundaryCondition2D,
    Channel,
    ConnectionNode,
    Control,
    ControlGroup,
    ControlMeasureGroup,
    ControlMeasureMap,
    ControlTable,
    CrossSectionDefinition,
    CrossSectionLocation,
    Culvert,
    DemAverageArea,
    GlobalSetting,
    GridRefinement,
    GridRefinementArea,
    Groundwater,
    ImperviousSurface,
    ImperviousSurfaceMap,
    Interflow,
    Lateral1D,
    Lateral2D,
    Levee,
    Manhole,
    NumericalSettings,
    Obstacle,
    Orifice,
    Pipe,
    Pumpstation,
    SimpleInfiltration,
    Surface,
    SurfaceMap,
    SurfaceParameters,
    Weir,
    Windshielding,
)
from utils.threedi_database import ThreediDatabase
from pathlib import Path

config = configparser.ConfigParser()
cwd = Path.cwd()
config_path = os.path.join(cwd,"code","datachecker","datachecker_config.ini")
print("Reading config file", config_path)

config.read( config_path)  # TODO make single config file
print(config["db"]["database"], "connected")
# %%

def get_parser():
    """Return argument parser."""

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "filename",
        default="model.sqlite",
        help="filename (including path) of the model",
    )
    return parser


def transform(wkt, srid_source, srid_dest):
    source_crs = osr.SpatialReference()
    source_crs.ImportFromEPSG(srid_source)
    dest_crs = osr.SpatialReference()
    dest_crs.ImportFromEPSG(srid_dest)
    transformation = osr.CoordinateTransformation(source_crs, dest_crs)

    point = ogr.CreateGeometryFromWkt(wkt)
    point.Transform(transformation)
    return point.ExportToWkt()


def export_threedi(**kwargs):
    filename = kwargs.get("filename")
    connection_nodes = []
    manholes = []
    pumpstations = []
    weirs = []
    orifices = []
    cross_section_definitions = []
    pipes = []
    impervious_surfaces = []
    impervious_surface_maps = []
    channels = []
    cross_section_locations = []
    culverts = []
    obstacles = []
    levees = []
    onedee_boundaries = []
    grid_refinement_areas = []
    grid_refinements = []
    surface_parameters = []
    surfaces = []
    surface_maps = []
    numerical_settings = []
    global_settings = []
    dem_average_areas = []
    windshieldings = []
    laterals_2d = []
    laterals_1d = []
    boundary_conditions_2d = []
    groundwaters = []
    interflows = []
    aggregation_settings = []
    simple_infiltrations = []

    control_groups = []
    control_measure_groups = []
    control_measure_maps = []
    controls = []
    control_tables = []

    sqlite_template = os.path.join(
        os.path.dirname(os.path.realpath(__file__)), "spatialite_template.sqlite"
    )
    shutil.copyfile(sqlite_template, filename)
    exportdb = ThreediDatabase({"db_file": filename, "db_path": filename})
    session = exportdb.get_session()
    for postgis_connection_node in execute_sql_statement(
        "select id,code,initial_waterlevel,storage_area,st_astext(st_transform(the_geom,4326)) from v2_connection_nodes",
        fetch=True,
    ):
        add_connection_node(connection_nodes, postgis_connection_node)
    for postgis_manhole in execute_sql_statement(
        "select id,code,display_name,surface_level,width,length,shape,bottom_level,calculation_type,manhole_indicator,connection_node_id from v2_manhole",
        fetch=True,
    ):
        add_manhole(manholes, postgis_manhole)
    for postgis_pipe in execute_sql_statement(
        "select id,display_name,code,profile_num,sewerage_type,calculation_type,invert_level_start_point,invert_level_end_point,cross_section_definition_id,friction_value,friction_type,dist_calc_points,material,original_length,zoom_category,connection_node_start_id,connection_node_end_id from v2_pipe",
        fetch=True,
    ):
        add_pipe(pipes, postgis_pipe)
    for postgis_orifice in execute_sql_statement(
        "select id,display_name,code,crest_level,sewerage,cross_section_definition_id,friction_value,friction_type,discharge_coefficient_positive,discharge_coefficient_negative,zoom_category,crest_type,connection_node_start_id,connection_node_end_id from v2_orifice",
        fetch=True,
    ):
        add_orifice(orifices, postgis_orifice)
    for postgis_pumpstation in execute_sql_statement(
        "select id,display_name,code,classification,sewerage,start_level,lower_stop_level,upper_stop_level,capacity,zoom_category,connection_node_start_id,connection_node_end_id,type from v2_pumpstation",
        fetch=True,
    ):
        add_pumpstation(pumpstations, postgis_pumpstation)
    for postgis_cross_section_definition in execute_sql_statement(
        "select id,shape,width,height,code from v2_cross_section_definition", fetch=True
    ):
        # Prevent height from being None
        if postgis_cross_section_definition[3] is None:
            height = "NULL"
        else:
            height = "'" + postgis_cross_section_definition[3] + "'"
        session.execute(
            text(
                "INSERT INTO v2_cross_section_definition(id,shape,width,height,code) VALUES({},'{}', '{}', {}, '{}')".format(
                    postgis_cross_section_definition[0],
                    postgis_cross_section_definition[1],
                    postgis_cross_section_definition[2],
                    height,
                    postgis_cross_section_definition[4],
                )
            )
        )

    for postgis_channel in execute_sql_statement(
        "select id,display_name,code,calculation_type,dist_calc_points,zoom_category,st_astext(st_transform(the_geom,4326)),connection_node_start_id,connection_node_end_id FROM v2_channel ",
        fetch=True,
    ):
        add_channel(channels, postgis_channel)

    for postgis_cross_section_location in execute_sql_statement(
        "select id,channel_id,definition_id,reference_level,friction_type,friction_value,bank_level,st_astext(st_transform(the_geom,4326)),code FROM v2_cross_section_location ",
        fetch=True,
    ):
        add_cross_section_location(
            cross_section_locations, postgis_cross_section_location
        )

    for postgis_weir in execute_sql_statement(
        "select id,display_name,code,crest_level,crest_type,cross_section_definition_id,sewerage,discharge_coefficient_positive,discharge_coefficient_negative,external,zoom_category,friction_value,friction_type,connection_node_start_id,connection_node_end_id FROM v2_weir",
        fetch=True,
    ):
        add_weir(weirs, postgis_weir)

    for postgis_culvert in execute_sql_statement(
        "select id,display_name,code,calculation_type,friction_value,friction_type,dist_calc_points,zoom_category,cross_section_definition_id,discharge_coefficient_positive,discharge_coefficient_negative,invert_level_start_point,invert_level_end_point,st_astext(st_transform(the_geom,4326)),connection_node_start_id,connection_node_end_id FROM v2_culvert",
        fetch=True,
    ):
        add_culvert(culverts, postgis_culvert)

    for postgis_obstacle in execute_sql_statement(
        "select id,crest_level,st_astext(st_transform(the_geom,4326)),code FROM v2_obstacle",
        fetch=True,
    ):
        add_obstacle(obstacles, postgis_obstacle)

    for postgis_levee in execute_sql_statement(
        "select id,crest_level,st_astext(st_transform(the_geom,4326)),material,max_breach_depth,code FROM v2_levee",
        fetch=True,
    ):
        add_levee(levees, postgis_levee)

    for postgis_impervious_surface in execute_sql_statement(
        "select id,display_name,code,surface_class,surface_sub_class,surface_inclination,zoom_category,nr_of_inhabitants,dry_weather_flow,area,st_astext(st_transform(the_geom,4326)) FROM v2_impervious_surface",
        fetch=True,
    ):
        add_impervious_surface(impervious_surfaces, postgis_impervious_surface)

    for postgis_impervious_surface_map in execute_sql_statement(
        "select id,impervious_surface_id,connection_node_id,percentage FROM v2_impervious_surface_map",
        fetch=True,
    ):
        add_impervious_surface_map(
            impervious_surface_maps, postgis_impervious_surface_map
        )

    for postgis_1d_boundary_condition in execute_sql_statement(
        "select id,connection_node_id,boundary_type,timeseries FROM v2_1d_boundary_conditions",
        fetch=True,
    ):
        add_1d_boundary_condition(onedee_boundaries, postgis_1d_boundary_condition)

    for postgis_grid_refinement_area in execute_sql_statement(
        "select id,display_name,refinement_level,code,st_astext(st_transform(the_geom,4326)) FROM v2_grid_refinement_area",
        fetch=True,
    ):
        add_grid_refinement_area(grid_refinement_areas, postgis_grid_refinement_area)

    for postgis_grid_refinement in execute_sql_statement(
        "select id,display_name,refinement_level,code,st_astext(st_transform(the_geom,4326)) FROM v2_grid_refinement",
        fetch=True,
    ):
        add_grid_refinement(grid_refinements, postgis_grid_refinement)

    for postgis_surface_parameter in execute_sql_statement(
        "select id,outflow_delay,surface_layer_thickness,infiltration,max_infiltration_capacity,min_infiltration_capacity,infiltration_decay_constant,infiltration_recovery_constant FROM v2_surface_parameters",
        fetch=True,
    ):
        add_surface_parameters(surface_parameters, postgis_surface_parameter)

    for postgis_surface in execute_sql_statement(
        "select id,display_name,code,zoom_category,nr_of_inhabitants,dry_weather_flow,function,area,surface_parameters_id,st_astext(st_transform(the_geom,4326)) FROM v2_surface",
        fetch=True,
    ):
        add_surfaces(surfaces, postgis_surface)

    for postgis_surface_map in execute_sql_statement(
        "select id,surface_type,surface_id,connection_node_id,percentage FROM v2_surface_map",
        fetch=True,
    ):
        add_surface_maps(surface_maps, postgis_surface_map)

    for postgis_numerical_setting in execute_sql_statement(
        "select id,cfl_strictness_factor_1d,cfl_strictness_factor_2d,convergence_cg,convergence_eps,flow_direction_threshold,frict_shallow_water_correction,general_numerical_threshold,integration_method,limiter_grad_1d,limiter_grad_2d,limiter_slope_crossectional_area_2d,limiter_slope_friction_2d,max_nonlin_iterations,max_degree,minimum_friction_velocity,minimum_surface_area,precon_cg,preissmann_slot,pump_implicit_ratio,thin_water_layer_definition,use_of_cg,use_of_nested_newton FROM v2_numerical_settings",
        fetch=True,
    ):
        add_numerical_settings(numerical_settings, postgis_numerical_setting)

    for postgis_global_setting in execute_sql_statement(
        "select id,use_2d_flow,use_1d_flow,manhole_storage_area,name,sim_time_step,output_time_step,nr_timesteps,start_time,start_date,grid_space,dist_calc_points,kmax,guess_dams,table_step_size,flooding_threshold,advection_1d,advection_2d,dem_file,frict_type,frict_coef,frict_coef_file,water_level_ini_type,initial_waterlevel,initial_waterlevel_file,interception_global,interception_file,dem_obstacle_detection,dem_obstacle_height,embedded_cutoff_threshold,epsg_code,timestep_plus,max_angle_1d_advection,minimum_sim_time_step,maximum_sim_time_step,frict_avg,wind_shielding_file,control_group_id,numerical_settings_id,use_0d_inflow,table_step_size_1d,table_step_size_volume_2d,use_2d_rain,initial_groundwater_level,initial_groundwater_level_file,initial_groundwater_level_type,groundwater_settings_id,simple_infiltration_settings_id,interflow_settings_id FROM v2_global_settings",
        fetch=True,
    ):
        add_global_settings(global_settings, postgis_global_setting)

    for postgis_dem_average_area in execute_sql_statement(
        "select id,st_astext(st_transform(the_geom,4326)) FROM v2_dem_average_area",
        fetch=True,
    ):
        add_dem_average_area(dem_average_areas, postgis_dem_average_area)

    for postgis_windshielding in execute_sql_statement(
        "select id,channel_id,north,northeast,east,southeast,south,southwest,west,northwest,st_astext(st_transform(the_geom,4326)) FROM v2_windshielding",
        fetch=True,
    ):
        add_windshielding(windshieldings, postgis_windshielding)

    for postgis_lateral2d in execute_sql_statement(
        "select id, type, st_astext(st_transform(the_geom,4326)), timeseries FROM v2_2d_lateral",
        fetch=True,
    ):
        add_2d_lateral(laterals_2d, postgis_lateral2d)

    for postgis_lateral1d in execute_sql_statement(
        "select id, connection_node_id, timeseries FROM v2_1d_lateral", fetch=True
    ):
        add_1d_lateral(laterals_1d, postgis_lateral1d)

    for postgis_boundary2d in execute_sql_statement(
        "select id, display_name, timeseries, boundary_type,st_astext(st_transform(the_geom,4326)) FROM v2_2d_boundary_conditions",
        fetch=True,
    ):
        add_2d_boundary(boundary_conditions_2d, postgis_boundary2d)

    for postgis_groundwater in execute_sql_statement(
        "select id, groundwater_impervious_layer_level, groundwater_impervious_layer_level_file, groundwater_impervious_layer_level_type, phreatic_storage_capacity, phreatic_storage_capacity_file, phreatic_storage_capacity_type, equilibrium_infiltration_rate, equilibrium_infiltration_rate_file, equilibrium_infiltration_rate_type, initial_infiltration_rate, initial_infiltration_rate_file, initial_infiltration_rate_type, infiltration_decay_period, infiltration_decay_period_file, infiltration_decay_period_type, groundwater_hydro_connectivity, groundwater_hydro_connectivity_file, groundwater_hydro_connectivity_type, display_name, leakage, leakage_file FROM v2_groundwater",
        fetch=True,
    ):
        add_groundwater(groundwaters, postgis_groundwater)

    for postgis_interflow in execute_sql_statement(
        "select id, interflow_type, porosity, porosity_file, porosity_layer_thickness, impervious_layer_elevation, hydraulic_conductivity, hydraulic_conductivity_file, display_name FROM v2_interflow",
        fetch=True,
    ):
        add_interflow(interflows, postgis_interflow)

    for postgis_aggregation_setting in execute_sql_statement(
        "select id, global_settings_id, var_name, flow_variable, aggregation_method, aggregation_in_space, timestep FROM v2_aggregation_settings",
        fetch=True,
    ):
        add_aggregation_setting(aggregation_settings, postgis_aggregation_setting)

    for postgis_simple_infiltration in execute_sql_statement(
        "select id, infiltration_rate, infiltration_rate_file, infiltration_surface_option, max_infiltration_capacity_file, display_name FROM v2_simple_infiltration",
        fetch=True,
    ):
        add_simple_infiltration(simple_infiltrations, postgis_simple_infiltration)

    for postgis_control_group in execute_sql_statement(
        "select id, name, description FROM v2_control_group",
        fetch=True,
    ):
        add_control_group(control_groups, postgis_control_group)

    for postgis_control_measure_group in execute_sql_statement(
        "select id FROM v2_control_measure_group",
        fetch=True,
    ):
        add_control_measure_group(control_measure_groups, postgis_control_measure_group)

    for postgis_control_measure_map in execute_sql_statement(
        "select id, measure_group_id, object_type, object_id, weight FROM v2_control_measure_map",
        fetch=True,
    ):
        add_control_measure_map(control_measure_maps, postgis_control_measure_map)

    for postgis_control in execute_sql_statement(
        'select id, control_group_id, control_type, control_id, measure_group_id, "start", "end", measure_frequency FROM v2_control',
        fetch=True,
    ):
        add_control(controls, postgis_control)

    for postgis_control_table in execute_sql_statement(
        "select id, action_type, measure_variable, target_type, target_id, measure_operator, action_table FROM v2_control_table",
        fetch=True,
    ):
        add_control_table(control_tables, postgis_control_table)

    export_to_db(
        session,
        connection_nodes,
        manholes,
        pipes,
        orifices,
        pumpstations,
        channels,
        cross_section_locations,
        weirs,
        culverts,
        obstacles,
        levees,
        impervious_surfaces,
        impervious_surface_maps,
        onedee_boundaries,
        grid_refinement_areas,
        grid_refinements,
        surface_parameters,
        surfaces,
        surface_maps,
        numerical_settings,
        global_settings,
        dem_average_areas,
        windshieldings,
        laterals_2d,
        laterals_1d,
        boundary_conditions_2d,
        groundwaters,
        interflows,
        aggregation_settings,
        simple_infiltrations,
        control_groups,
        control_measure_groups,
        control_measure_maps,
        controls,
        control_tables,
    )


def export_to_db(
    session,
    connection_nodes,
    manholes,
    pipes,
    orifices,
    pumpstations,
    channels,
    cross_section_locations,
    weirs,
    culverts,
    obstacles,
    levees,
    impervious_surfaces,
    impervious_surface_maps,
    onedee_boundaries,
    grid_refinement_areas,
    grid_refinements,
    surface_parameters,
    surfaces,
    surface_maps,
    numerical_settings,
    global_settings,
    dem_average_areas,
    windshieldings,
    laterals_2d,
    laterals_1d,
    boundary_conditions_2d,
    groundwaters,
    interflows,
    aggregation_settings,
    simple_infiltrations,
    control_groups,
    control_measure_groups,
    control_measure_maps,
    controls,
    control_tables,
):
    commit_counts = {}
    connection_node_list = []
    for connection_node in connection_nodes:
        connection_node_list.append(
            ConnectionNode(
                id=connection_node["id"],
                code=connection_node["code"],
                initial_waterlevel=connection_node["initial_waterlevel"],
                storage_area=connection_node["storage_area"],
                the_geom=connection_node["the_geom"],
            )
        )
    commit_counts["connection_nodes"] = len(connection_node_list)
    session.bulk_save_objects(connection_node_list)
    session.commit()

    manh_list = []
    for manhole in manholes:
        manh_list.append(
            Manhole(
                id=manhole["id"],
                code=manhole["code"],
                display_name=manhole["display_name"],
                surface_level=manhole["surface_level"],
                width=manhole["width"],
                length=manhole["length"],
                shape=manhole["shape"],
                bottom_level=manhole["bottom_level"],
                calculation_type=manhole["calculation_type"],
                manhole_indicator=manhole["manhole_indicator"],
                connection_node_id=manhole["connection_node_id"],
            )
        )
    commit_counts["manholes"] = len(manh_list)
    session.bulk_save_objects(manh_list)
    session.commit()

    pipe_list = []
    for pipe in pipes:
        pipe_list.append(
            Pipe(
                id=pipe["id"],
                display_name=pipe["display_name"],
                code=pipe["code"],
                profile_num=pipe["profile_num"],
                sewerage_type=pipe["sewerage_type"],
                calculation_type=pipe["calculation_type"],
                invert_level_start_point=pipe["invert_level_start_point"],
                invert_level_end_point=pipe["invert_level_end_point"],
                cross_section_definition_id=pipe["cross_section_definition_id"],
                friction_value=pipe["friction_value"],
                friction_type=pipe["friction_type"],
                dist_calc_points=pipe["dist_calc_points"],
                material=pipe["material"],
                original_length=pipe["original_length"],
                zoom_category=pipe["zoom_category"],
                connection_node_start_id=pipe["connection_node_start_id"],
                connection_node_end_id=pipe["connection_node_end_id"],
            )
        )
    commit_counts["pipes"] = len(pipe_list)
    session.bulk_save_objects(pipe_list)
    session.commit()

    orifice_list = []
    for orifice in orifices:
        orifice_list.append(
            Orifice(
                id=orifice["id"],
                display_name=orifice["display_name"],
                code=orifice["code"],
                crest_level=orifice["crest_level"],
                sewerage=orifice["sewerage"],
                cross_section_definition_id=orifice["cross_section_definition_id"],
                friction_value=orifice["friction_value"],
                friction_type=orifice["friction_type"],
                discharge_coefficient_positive=orifice[
                    "discharge_coefficient_positive"
                ],
                discharge_coefficient_negative=orifice[
                    "discharge_coefficient_negative"
                ],
                zoom_category=orifice["zoom_category"],
                crest_type=orifice["crest_type"],
                connection_node_start_id=orifice["connection_node_start_id"],
                connection_node_end_id=orifice["connection_node_end_id"],
            )
        )
    commit_counts["orifices"] = len(orifice_list)
    session.bulk_save_objects(orifice_list)
    session.commit()

    pumpstation_list = []
    for pumpstation in pumpstations:
        pumpstation_list.append(
            Pumpstation(
                id=pumpstation["id"],
                display_name=pumpstation["display_name"],
                code=pumpstation["code"],
                classification=pumpstation["classification"],
                sewerage=pumpstation["sewerage"],
                start_level=pumpstation["start_level"],
                lower_stop_level=pumpstation["lower_stop_level"],
                upper_stop_level=pumpstation["upper_stop_level"],
                capacity=pumpstation["capacity"],
                zoom_category=pumpstation["zoom_category"],
                connection_node_start_id=pumpstation["connection_node_start_id"],
                connection_node_end_id=pumpstation["connection_node_end_id"],
                type_=pumpstation["type"],
            )
        )
    commit_counts["pumpstations"] = len(pumpstation_list)
    session.bulk_save_objects(pumpstation_list)
    session.commit()

    channel_list = []
    for channel in channels:
        channel_list.append(
            Channel(
                id=channel["id"],
                display_name=channel["display_name"],
                code=channel["code"],
                calculation_type=channel["calculation_type"],
                dist_calc_points=channel["dist_calc_points"],
                zoom_category=channel["zoom_category"],
                the_geom=channel["the_geom"],
                connection_node_start_id=channel["connection_node_start_id"],
                connection_node_end_id=channel["connection_node_end_id"],
            )
        )
    commit_counts["channels"] = len(channel_list)
    session.bulk_save_objects(channel_list)
    session.commit()

    cross_section_location_list = []
    for cross_section_location in cross_section_locations:
        cross_section_location_list.append(
            CrossSectionLocation(
                id=cross_section_location["id"],
                channel_id=cross_section_location["channel_id"],
                definition_id=cross_section_location["definition_id"],
                reference_level=cross_section_location["reference_level"],
                friction_type=cross_section_location["friction_type"],
                friction_value=cross_section_location["friction_value"],
                bank_level=cross_section_location["bank_level"],
                the_geom=cross_section_location["the_geom"],
                code=cross_section_location["code"],
            )
        )
    commit_counts["cross_section_locations"] = len(cross_section_location_list)
    session.bulk_save_objects(cross_section_location_list)
    session.commit()

    weir_list = []
    for weir in weirs:
        weir_list.append(
            Weir(
                id=weir["id"],
                display_name=weir["display_name"],
                code=weir["code"],
                crest_level=weir["crest_level"],
                crest_type=weir["crest_type"],
                cross_section_definition_id=weir["cross_section_definition_id"],
                sewerage=weir["sewerage"],
                discharge_coefficient_positive=weir["discharge_coefficient_positive"],
                discharge_coefficient_negative=weir["discharge_coefficient_negative"],
                external=weir["external"],
                zoom_category=weir["zoom_category"],
                friction_value=weir["friction_value"],
                friction_type=weir["friction_type"],
                connection_node_start_id=weir["connection_node_start_id"],
                connection_node_end_id=weir["connection_node_end_id"],
            )
        )
    commit_counts["weirs"] = len(weir_list)
    session.bulk_save_objects(weir_list)
    session.commit()

    culvert_list = []
    for culvert in culverts:
        culvert_list.append(
            Culvert(
                id=culvert["id"],
                display_name=culvert["display_name"],
                code=culvert["code"],
                calculation_type=culvert["calculation_type"],
                friction_value=culvert["friction_value"],
                friction_type=culvert["friction_type"],
                dist_calc_points=culvert["dist_calc_points"],
                zoom_category=culvert["zoom_category"],
                cross_section_definition_id=culvert["cross_section_definition_id"],
                discharge_coefficient_positive=culvert[
                    "discharge_coefficient_positive"
                ],
                discharge_coefficient_negative=culvert[
                    "discharge_coefficient_negative"
                ],
                invert_level_start_point=culvert["invert_level_start_point"],
                invert_level_end_point=culvert["invert_level_end_point"],
                the_geom=culvert["the_geom"],
                connection_node_start_id=culvert["connection_node_start_id"],
                connection_node_end_id=culvert["connection_node_end_id"],
            )
        )
    commit_counts["culverts"] = len(culvert_list)
    session.bulk_save_objects(culvert_list)
    session.commit()

    obstacle_list = []
    for obstacle in obstacles:
        obstacle_list.append(
            Obstacle(
                id=obstacle["id"],
                crest_level=obstacle["crest_level"],
                the_geom=obstacle["the_geom"],
                code=obstacle["code"],
            )
        )
    commit_counts["obstacles"] = len(obstacle_list)
    session.bulk_save_objects(obstacle_list)
    session.commit()

    levee_list = []
    for levee in levees:
        levee_list.append(
            Levee(
                id=levee["id"],
                crest_level=levee["crest_level"],
                the_geom=levee["the_geom"],
                material=levee["material"],
                max_breach_depth=levee["max_breach_depth"],
                code=levee["code"],
            )
        )
    commit_counts["levees"] = len(levee_list)
    session.bulk_save_objects(levee_list)
    session.commit()

    impervious_surface_list = []
    for impervious_surface in impervious_surfaces:
        impervious_surface_list.append(
            ImperviousSurface(
                id=impervious_surface["id"],
                display_name=impervious_surface["display_name"],
                code=impervious_surface["code"],
                surface_class=impervious_surface["surface_class"],
                surface_sub_class=impervious_surface["surface_sub_class"],
                surface_inclination=impervious_surface["surface_inclination"],
                zoom_category=impervious_surface["zoom_category"],
                nr_of_inhabitants=impervious_surface["nr_of_inhabitants"],
                dry_weather_flow=impervious_surface["dry_weather_flow"],
                area=impervious_surface["area"],
                the_geom=impervious_surface["the_geom"],
            )
        )
    commit_counts["impervious_surfaces"] = len(impervious_surface_list)
    session.bulk_save_objects(impervious_surface_list)
    session.commit()

    impervious_surface_map_list = []
    for impervious_surface_map in impervious_surface_maps:
        impervious_surface_map_list.append(
            ImperviousSurfaceMap(
                id=impervious_surface_map["id"],
                impervious_surface_id=impervious_surface_map["impervious_surface_id"],
                connection_node_id=impervious_surface_map["connection_node_id"],
                percentage=impervious_surface_map["percentage"],
            )
        )
    commit_counts["impervious_surface_maps"] = len(impervious_surface_map_list)
    session.bulk_save_objects(impervious_surface_map_list)
    session.commit()

    onedee_boundary_list = []
    for onedee_boundary in onedee_boundaries:
        onedee_boundary_list.append(
            BoundaryCondition1D(
                id=onedee_boundary["id"],
                connection_node_id=onedee_boundary["connection_node_id"],
                boundary_type=onedee_boundary["boundary_type"],
                timeseries=onedee_boundary["timeseries"],
            )
        )
    commit_counts["1d_boundaries"] = len(onedee_boundary_list)
    session.bulk_save_objects(onedee_boundary_list)
    session.commit()

    grid_refinement_area_list = []
    for grid_refinement_area in grid_refinement_areas:
        grid_refinement_area_list.append(
            GridRefinementArea(
                id=grid_refinement_area["id"],
                display_name=grid_refinement_area["display_name"],
                refinement_level=grid_refinement_area["refinement_level"],
                code=grid_refinement_area["code"],
                the_geom=grid_refinement_area["the_geom"],
            )
        )
    commit_counts["grid_refinement_area"] = len(grid_refinement_area_list)
    session.bulk_save_objects(grid_refinement_area_list)
    session.commit()

    grid_refinement_list = []
    for grid_refinement in grid_refinements:
        grid_refinement_list.append(
            GridRefinement(
                id=grid_refinement["id"],
                display_name=grid_refinement["display_name"],
                refinement_level=grid_refinement["refinement_level"],
                code=grid_refinement["code"],
                the_geom=grid_refinement["the_geom"],
            )
        )
    commit_counts["grid_refinement"] = len(grid_refinement_list)
    session.bulk_save_objects(grid_refinement_list)
    session.commit()

    surface_parameters_list = []
    for surface_parameter in surface_parameters:
        surface_parameters_list.append(
            SurfaceParameters(
                id=surface_parameter["id"],
                outflow_delay=surface_parameter["outflow_delay"],
                surface_layer_thickness=surface_parameter["surface_layer_thickness"],
                infiltration=surface_parameter["infiltration"],
                max_infiltration_capacity=surface_parameter[
                    "max_infiltration_capacity"
                ],
                min_infiltration_capacity=surface_parameter[
                    "min_infiltration_capacity"
                ],
                infiltration_decay_constant=surface_parameter[
                    "infiltration_decay_constant"
                ],
                infiltration_recovery_constant=surface_parameter[
                    "infiltration_recovery_constant"
                ],
            )
        )
    commit_counts["surface_parameters"] = len(surface_parameters_list)
    session.bulk_save_objects(surface_parameters_list)
    session.commit()

    surfaces_list = []
    for surface in surfaces:
        surfaces_list.append(
            Surface(
                id=surface["id"],
                display_name=surface["display_name"],
                code=surface["code"],
                zoom_category=surface["zoom_category"],
                nr_of_inhabitants=surface["nr_of_inhabitants"],
                dry_weather_flow=surface["dry_weather_flow"],
                area=surface["area"],
                surface_parameters_id=surface["surface_parameters_id"],
                the_geom=surface["the_geom"],
            )
        )
    commit_counts["surfaces"] = len(surfaces_list)
    session.bulk_save_objects(surfaces_list)
    session.commit()

    surface_maps_list = []
    for surface_map in surface_maps:
        surface_maps_list.append(
            SurfaceMap(
                id=surface_map["id"],
                surface_type=surface_map["surface_type"],
                surface_id=surface_map["surface_id"],
                connection_node_id=surface_map["connection_node_id"],
                percentage=surface_map["percentage"],
            )
        )
    commit_counts["surface_maps"] = len(surface_maps_list)
    session.bulk_save_objects(surface_maps_list)
    session.commit()

    numerical_settings_list = []
    for numerical_setting in numerical_settings:
        numerical_settings_list.append(
            NumericalSettings(
                id=numerical_setting["id"],
                cfl_strictness_factor_1d=numerical_setting["cfl_strictness_factor_1d"],
                cfl_strictness_factor_2d=numerical_setting["cfl_strictness_factor_2d"],
                convergence_cg=numerical_setting["convergence_cg"],
                convergence_eps=numerical_setting["convergence_eps"],
                flow_direction_threshold=numerical_setting["flow_direction_threshold"],
                frict_shallow_water_correction=numerical_setting[
                    "frict_shallow_water_correction"
                ],
                general_numerical_threshold=numerical_setting[
                    "general_numerical_threshold"
                ],
                integration_method=numerical_setting["integration_method"],
                limiter_grad_1d=numerical_setting["limiter_grad_1d"],
                limiter_grad_2d=numerical_setting["limiter_grad_2d"],
                limiter_slope_crossectional_area_2d=numerical_setting[
                    "limiter_slope_crossectional_area_2d"
                ],
                limiter_slope_friction_2d=numerical_setting[
                    "limiter_slope_friction_2d"
                ],
                max_nonlin_iterations=numerical_setting["max_nonlin_iterations"],
                max_degree=numerical_setting["max_degree"],
                minimum_friction_velocity=numerical_setting[
                    "minimum_friction_velocity"
                ],
                minimum_surface_area=numerical_setting["minimum_surface_area"],
                precon_cg=numerical_setting["precon_cg"],
                preissmann_slot=numerical_setting["preissmann_slot"],
                pump_implicit_ratio=numerical_setting["pump_implicit_ratio"],
                thin_water_layer_definition=numerical_setting[
                    "thin_water_layer_definition"
                ],
                use_of_cg=numerical_setting["use_of_cg"],
                use_of_nested_newton=numerical_setting["use_of_nested_newton"],
            )
        )
    commit_counts["numerical_setting"] = len(numerical_settings_list)
    session.bulk_save_objects(numerical_settings_list)
    session.commit()

    global_settings_list = []
    for global_setting in global_settings:
        global_settings_list.append(
            GlobalSetting(
                id=global_setting["id"],
                use_2d_flow=global_setting["use_2d_flow"],
                use_1d_flow=global_setting["use_1d_flow"],
                manhole_storage_area=global_setting["manhole_storage_area"],
                name=global_setting["name"],
                sim_time_step=global_setting["sim_time_step"],
                output_time_step=global_setting["output_time_step"],
                nr_timesteps=global_setting["nr_timesteps"],
                start_time=global_setting["start_time"],
                start_date=global_setting["start_date"],
                grid_space=global_setting["grid_space"],
                dist_calc_points=global_setting["dist_calc_points"],
                kmax=global_setting["kmax"],
                guess_dams=global_setting["guess_dams"],
                table_step_size=global_setting["table_step_size"],
                flooding_threshold=global_setting["flooding_threshold"],
                advection_1d=global_setting["advection_1d"],
                advection_2d=global_setting["advection_2d"],
                dem_file=global_setting["dem_file"],
                frict_type=global_setting["frict_type"],
                frict_coef=global_setting["frict_coef"],
                frict_coef_file=global_setting["frict_coef_file"],
                water_level_ini_type=global_setting["water_level_ini_type"],
                initial_waterlevel=global_setting["initial_waterlevel"],
                initial_waterlevel_file=global_setting["initial_waterlevel_file"],
                interception_global=global_setting["interception_global"],
                interception_file=global_setting["interception_file"],
                dem_obstacle_detection=global_setting["dem_obstacle_detection"],
                dem_obstacle_height=global_setting["dem_obstacle_height"],
                embedded_cutoff_threshold=global_setting["embedded_cutoff_threshold"],
                epsg_code=global_setting["epsg_code"],
                timestep_plus=global_setting["timestep_plus"],
                max_angle_1d_advection=global_setting["max_angle_1d_advection"],
                minimum_sim_time_step=global_setting["minimum_sim_time_step"],
                maximum_sim_time_step=global_setting["maximum_sim_time_step"],
                frict_avg=global_setting["frict_avg"],
                wind_shielding_file=global_setting["wind_shielding_file"],
                control_group_id=global_setting["control_group_id"],
                numerical_settings_id=global_setting["numerical_settings_id"],
                use_0d_inflow=global_setting["use_0d_inflow"],
                table_step_size_1d=global_setting["table_step_size_1d"],
                table_step_size_volume_2d=global_setting["table_step_size_volume_2d"],
                use_2d_rain=global_setting["use_2d_rain"],
                initial_groundwater_level=global_setting["initial_groundwater_level"],
                initial_groundwater_level_file=global_setting[
                    "initial_groundwater_level_file"
                ],
                initial_groundwater_level_type=global_setting[
                    "initial_groundwater_level_type"
                ],
                groundwater_settings_id=global_setting["groundwater_settings_id"],
                simple_infiltration_settings_id=global_setting[
                    "simple_infiltration_settings_id"
                ],
                interflow_settings_id=global_setting["interflow_settings_id"],
            )
        )
    commit_counts["global_setting"] = len(global_settings_list)
    session.bulk_save_objects(global_settings_list)
    session.commit()

    dem_average_areas_list = []
    for dem_average_area in dem_average_areas:
        dem_average_areas_list.append(
            DemAverageArea(
                id=dem_average_area["id"], the_geom=dem_average_area["the_geom"]
            )
        )
    commit_counts["dem_average_areas"] = len(dem_average_areas_list)
    session.bulk_save_objects(dem_average_areas_list)
    session.commit()

    windshieldings_list = []
    for windshielding in windshieldings:
        windshieldings_list.append(
            Windshielding(
                id=windshielding["id"],
                channel_id=windshielding["channel_id"],
                north=windshielding["north"],
                northeast=windshielding["northeast"],
                east=windshielding["east"],
                southeast=windshielding["southeast"],
                south=windshielding["south"],
                southwest=windshielding["southwest"],
                west=windshielding["west"],
                northwest=windshielding["northwest"],
                the_geom=windshielding["the_geom"],
            )
        )
    commit_counts["windshieldings"] = len(windshieldings_list)
    session.bulk_save_objects(windshieldings_list)
    session.commit()

    laterals_2d_list = []
    for lateral_2d in laterals_2d:
        laterals_2d_list.append(
            Lateral2D(
                id=lateral_2d["id"],
                type=lateral_2d["type"],
                the_geom=lateral_2d["the_geom"],
                timeseries=lateral_2d["timeseries"],
            )
        )
    commit_counts["laterals_2d"] = len(laterals_2d_list)
    session.bulk_save_objects(laterals_2d_list)
    session.commit()

    laterals_1d_list = []
    for lateral_1d in laterals_1d:
        laterals_1d_list.append(
            Lateral1D(
                id=lateral_1d["id"],
                connection_node_id=lateral_1d["connection_node_id"],
                timeseries=lateral_1d["timeseries"],
            )
        )
    commit_counts["laterals_1d"] = len(laterals_1d_list)
    session.bulk_save_objects(laterals_1d_list)
    session.commit()

    boundaries_2d_list = []
    for boundary_condition_2d in boundary_conditions_2d:
        boundaries_2d_list.append(
            BoundaryCondition2D(
                id=boundary_condition_2d["id"],
                display_name=boundary_condition_2d["display_name"],
                timeseries=boundary_condition_2d["timeseries"],
                boundary_type=boundary_condition_2d["boundary_type"],
                the_geom=boundary_condition_2d["the_geom"],
            )
        )
    commit_counts["boundaries_2d"] = len(boundaries_2d_list)
    session.bulk_save_objects(boundaries_2d_list)
    session.commit()

    groundwater_list = []
    for groundwater in groundwaters:
        groundwater_list.append(
            Groundwater(
                id=groundwater["id"],
                groundwater_impervious_layer_level=groundwater[
                    "groundwater_impervious_layer_level"
                ],
                groundwater_impervious_layer_level_file=groundwater[
                    "groundwater_impervious_layer_level_file"
                ],
                groundwater_impervious_layer_level_type=groundwater[
                    "groundwater_impervious_layer_level_type"
                ],
                phreatic_storage_capacity=groundwater["phreatic_storage_capacity"],
                phreatic_storage_capacity_file=groundwater[
                    "phreatic_storage_capacity_file"
                ],
                phreatic_storage_capacity_type=groundwater[
                    "phreatic_storage_capacity_type"
                ],
                equilibrium_infiltration_rate=groundwater[
                    "equilibrium_infiltration_rate"
                ],
                equilibrium_infiltration_rate_file=groundwater[
                    "equilibrium_infiltration_rate_file"
                ],
                equilibrium_infiltration_rate_type=groundwater[
                    "equilibrium_infiltration_rate_type"
                ],
                initial_infiltration_rate=groundwater["initial_infiltration_rate"],
                initial_infiltration_rate_file=groundwater[
                    "initial_infiltration_rate_file"
                ],
                initial_infiltration_rate_type=groundwater[
                    "initial_infiltration_rate_type"
                ],
                infiltration_decay_period=groundwater["infiltration_decay_period"],
                infiltration_decay_period_file=groundwater[
                    "infiltration_decay_period_file"
                ],
                infiltration_decay_period_type=groundwater[
                    "infiltration_decay_period_type"
                ],
                groundwater_hydro_connectivity=groundwater[
                    "groundwater_hydro_connectivity"
                ],
                groundwater_hydro_connectivity_file=groundwater[
                    "groundwater_hydro_connectivity_file"
                ],
                groundwater_hydro_connectivity_type=groundwater[
                    "groundwater_hydro_connectivity_type"
                ],
                display_name=groundwater["display_name"],
                leakage=groundwater["leakage"],
                leakage_file=groundwater["leakage_file"],
            )
        )
    commit_counts["groundwater"] = len(groundwater_list)
    session.bulk_save_objects(groundwater_list)
    session.commit()

    interflow_list = []
    for interflow in interflows:
        interflow_list.append(
            Interflow(
                id=interflow["id"],
                interflow_type=interflow["interflow_type"],
                porosity=interflow["porosity"],
                porosity_file=interflow["porosity_file"],
                porosity_layer_thickness=interflow["porosity_layer_thickness"],
                impervious_layer_elevation=interflow["impervious_layer_elevation"],
                hydraulic_conductivity=interflow["hydraulic_conductivity"],
                hydraulic_conductivity_file=interflow["hydraulic_conductivity_file"],
                display_name=interflow["display_name"],
            )
        )
    commit_counts["interflow"] = len(interflow_list)
    session.bulk_save_objects(interflow_list)
    session.commit()

    aggregation_settings_list = []
    for aggregation_setting in aggregation_settings:
        aggregation_settings_list.append(
            AggregationSettings(
                id=aggregation_setting["id"],
                global_settings_id=aggregation_setting["global_settings_id"],
                var_name=aggregation_setting["var_name"],
                flow_variable=aggregation_setting["flow_variable"],
                aggregation_method=aggregation_setting["aggregation_method"],
                aggregation_in_space=aggregation_setting["aggregation_in_space"],
                timestep=aggregation_setting["timestep"],
            )
        )
    commit_counts["aggregation_settings"] = len(aggregation_settings_list)
    session.bulk_save_objects(aggregation_settings_list)
    session.commit()

    simple_infiltrations_list = []
    for simple_infiltration in simple_infiltrations:
        simple_infiltrations_list.append(
            SimpleInfiltration(
                id=simple_infiltration["id"],
                infiltration_rate=simple_infiltration["infiltration_rate"],
                infiltration_rate_file=simple_infiltration["infiltration_rate_file"],
                infiltration_surface_option=simple_infiltration[
                    "infiltration_surface_option"
                ],
                max_infiltration_capacity_file=simple_infiltration[
                    "max_infiltration_capacity_file"
                ],
                display_name=simple_infiltration["display_name"],
            )
        )
    commit_counts["simple_infiltration_settings"] = len(simple_infiltrations_list)
    session.bulk_save_objects(simple_infiltrations_list)
    session.commit()

    control_groups_list = []
    for control_group in control_groups:
        control_groups_list.append(
            ControlGroup(
                id=control_group["id"],
                name=control_group["name"],
                description=control_group["description"],
            )
        )
    commit_counts["control_group"] = len(control_groups_list)
    session.bulk_save_objects(control_groups_list)
    session.commit()

    control_measure_groups_list = []
    for control_measure_group in control_measure_groups:
        control_measure_groups_list.append(
            ControlMeasureGroup(
                id=control_measure_group["id"],
            )
        )
    commit_counts["control_measure_group"] = len(control_measure_groups_list)
    session.bulk_save_objects(control_measure_groups_list)
    session.commit()

    control_measure_maps_list = []
    for control_measure_map in control_measure_maps:
        control_measure_maps_list.append(
            ControlMeasureMap(
                id=control_measure_map["id"],
                measure_group_id=control_measure_map["measure_group_id"],
                object_type=control_measure_map["object_type"],
                object_id=control_measure_map["object_id"],
                weight=control_measure_map["weight"],
            )
        )
    commit_counts["control_measure_map"] = len(control_measure_maps_list)
    session.bulk_save_objects(control_measure_maps_list)
    session.commit()

    controls_list = []
    for control in controls:
        controls_list.append(
            Control(
                id=control["id"],
                control_group_id=control["control_group_id"],
                control_type=control["control_type"],
                control_id=control["control_id"],
                measure_group_id=control["measure_group_id"],
                start=control["start"],
                end=control["end"],
                measure_frequency=control["measure_frequency"],
            )
        )
    commit_counts["control"] = len(controls_list)
    session.bulk_save_objects(controls_list)
    session.commit()

    control_tables_list = []
    for control_table in control_tables:
        control_tables_list.append(
            ControlTable(
                id=control_table["id"],
                action_type=control_table["action_type"],
                measure_variable=control_table["measure_variable"],
                target_type=control_table["target_type"],
                target_id=control_table["target_id"],
                measure_operator=control_table["measure_operator"],
                action_table=control_table["action_table"],
            )
        )
    commit_counts["control_table"] = len(control_tables_list)
    session.bulk_save_objects(control_tables_list)
    session.commit()


def add_connection_node(connection_nodes, postgis_connection_node):
    """Add hydx.connection_node into threedi.connection_node and threedi.manhole"""

    # get connection_nodes attributes
    connection_node = {
        "id": postgis_connection_node[0],
        "code": postgis_connection_node[1],
        "initial_waterlevel": postgis_connection_node[2],
        "storage_area": postgis_connection_node[3],
        "the_geom": "srid={0};{1}".format(4326, postgis_connection_node[4]),
    }

    connection_nodes.append(connection_node)
    return connection_nodes


def add_manhole(manholes, postgis_manhole):
    manhole = {
        "id": postgis_manhole[0],
        "code": postgis_manhole[1],
        "display_name": postgis_manhole[2],
        "surface_level": postgis_manhole[3],
        "width": postgis_manhole[4],
        "length": postgis_manhole[5],
        "shape": postgis_manhole[6],
        "bottom_level": postgis_manhole[7],
        "calculation_type": postgis_manhole[8],
        "manhole_indicator": postgis_manhole[9],
        "connection_node_id": postgis_manhole[10],
    }
    manholes.append(manhole)
    return manholes


def add_pipe(pipes, postgis_pipe):
    pipe = {
        "id": postgis_pipe[0],
        "display_name": postgis_pipe[1],
        "code": postgis_pipe[2],
        "profile_num": postgis_pipe[3],
        "sewerage_type": postgis_pipe[4],
        "calculation_type": postgis_pipe[5],
        "invert_level_start_point": postgis_pipe[6],
        "invert_level_end_point": postgis_pipe[7],
        "cross_section_definition_id": postgis_pipe[8],
        "friction_value": postgis_pipe[9],
        "friction_type": postgis_pipe[10],
        "dist_calc_points": postgis_pipe[11],
        "material": postgis_pipe[12],
        "original_length": postgis_pipe[13],
        "zoom_category": postgis_pipe[14],
        "connection_node_start_id": postgis_pipe[15],
        "connection_node_end_id": postgis_pipe[16],
    }
    pipes.append(pipe)
    return pipes


def add_orifice(orifices, postgis_orifice):
    orifice = {
        "id": postgis_orifice[0],
        "display_name": postgis_orifice[1],
        "code": postgis_orifice[2],
        "crest_level": postgis_orifice[3],
        "sewerage": postgis_orifice[4],
        "cross_section_definition_id": postgis_orifice[5],
        "friction_value": postgis_orifice[6],
        "friction_type": postgis_orifice[7],
        "discharge_coefficient_positive": postgis_orifice[8],
        "discharge_coefficient_negative": postgis_orifice[9],
        "zoom_category": postgis_orifice[10],
        "crest_type": postgis_orifice[11],
        "connection_node_start_id": postgis_orifice[12],
        "connection_node_end_id": postgis_orifice[13],
    }
    orifices.append(orifice)
    return orifices


def add_pumpstation(pumpstations, postgis_pumpstation):
    pumpstation = {
        "id": postgis_pumpstation[0],
        "display_name": postgis_pumpstation[1],
        "code": postgis_pumpstation[2],
        "classification": postgis_pumpstation[3],
        "sewerage": postgis_pumpstation[4],
        "start_level": postgis_pumpstation[5],
        "lower_stop_level": postgis_pumpstation[6],
        "upper_stop_level": postgis_pumpstation[7],
        "capacity": postgis_pumpstation[8],
        "zoom_category": postgis_pumpstation[9],
        "connection_node_start_id": postgis_pumpstation[10],
        "connection_node_end_id": postgis_pumpstation[11],
        "type": postgis_pumpstation[12],
    }
    pumpstations.append(pumpstation)
    return pumpstations


def add_channel(channels, postgis_channel):
    channel = {
        "id": postgis_channel[0],
        "display_name": postgis_channel[1],
        "code": postgis_channel[2],
        "calculation_type": postgis_channel[3],
        "dist_calc_points": postgis_channel[4],
        "zoom_category": postgis_channel[5],
        "the_geom": "srid={0};{1}".format(4326, postgis_channel[6]),
        "connection_node_start_id": postgis_channel[7],
        "connection_node_end_id": postgis_channel[8],
    }
    channels.append(channel)
    return channels


def add_cross_section_location(cross_section_locations, postgis_cross_section_location):
    cross_section_location = {
        "id": postgis_cross_section_location[0],
        "channel_id": postgis_cross_section_location[1],
        "definition_id": postgis_cross_section_location[2],
        "reference_level": postgis_cross_section_location[3],
        "friction_type": postgis_cross_section_location[4],
        "friction_value": postgis_cross_section_location[5],
        "bank_level": postgis_cross_section_location[6],
        "the_geom": "srid={0};{1}".format(4326, postgis_cross_section_location[7]),
        "code": postgis_cross_section_location[8],
    }
    cross_section_locations.append(cross_section_location)
    return cross_section_location


def add_weir(weirs, postgis_weir):
    weir = {
        "id": postgis_weir[0],
        "display_name": postgis_weir[1],
        "code": postgis_weir[2],
        "crest_level": postgis_weir[3],
        "crest_type": postgis_weir[4],
        "cross_section_definition_id": postgis_weir[5],
        "sewerage": postgis_weir[6],
        "discharge_coefficient_positive": postgis_weir[7],
        "discharge_coefficient_negative": postgis_weir[8],
        "external": postgis_weir[9],
        "zoom_category": postgis_weir[10],
        "friction_value": postgis_weir[11],
        "friction_type": postgis_weir[12],
        "connection_node_start_id": postgis_weir[13],
        "connection_node_end_id": postgis_weir[14],
    }
    weirs.append(weir)
    return weirs


def add_culvert(culverts, postgis_culvert):
    culvert = {
        "id": postgis_culvert[0],
        "display_name": postgis_culvert[1],
        "code": postgis_culvert[2],
        "calculation_type": postgis_culvert[3],
        "friction_value": postgis_culvert[4],
        "friction_type": postgis_culvert[5],
        "dist_calc_points": postgis_culvert[6],
        "zoom_category": postgis_culvert[7],
        "cross_section_definition_id": postgis_culvert[8],
        "discharge_coefficient_positive": postgis_culvert[9],
        "discharge_coefficient_negative": postgis_culvert[10],
        "invert_level_start_point": postgis_culvert[11],
        "invert_level_end_point": postgis_culvert[12],
        "the_geom": "srid={0};{1}".format(4326, postgis_culvert[13]),
        "connection_node_start_id": postgis_culvert[14],
        "connection_node_end_id": postgis_culvert[15],
    }
    culverts.append(culvert)
    return culverts


def add_obstacle(obstacles, postgis_obstacle):
    obstacle = {
        "id": postgis_obstacle[0],
        "crest_level": postgis_obstacle[1],
        "the_geom": "srid={0};{1}".format(4326, postgis_obstacle[2]),
        "code": postgis_obstacle[3],
    }
    obstacles.append(obstacle)
    return obstacles


def add_levee(levees, postgis_levee):
    levee = {
        "id": postgis_levee[0],
        "crest_level": postgis_levee[1],
        "the_geom": "srid={0};{1}".format(4326, postgis_levee[2]),
        "material": postgis_levee[3],
        "max_breach_depth": postgis_levee[4],
        "code": postgis_levee[5],
    }
    levees.append(levee)
    return levees


def add_impervious_surface(impervious_surfaces, postgis_impervious_surface):
    impervious_surface = {
        "id": postgis_impervious_surface[0],
        "display_name": postgis_impervious_surface[1],
        "code": postgis_impervious_surface[2],
        "surface_class": postgis_impervious_surface[3],
        "surface_sub_class": postgis_impervious_surface[4],
        "surface_inclination": postgis_impervious_surface[5],
        "zoom_category": postgis_impervious_surface[6],
        "nr_of_inhabitants": postgis_impervious_surface[7],
        "dry_weather_flow": postgis_impervious_surface[8],
        "area": postgis_impervious_surface[9],
        "the_geom": "srid={0};{1}".format(4326, postgis_impervious_surface[10]),
    }
    impervious_surfaces.append(impervious_surface)
    return impervious_surfaces


def add_impervious_surface_map(impervious_surface_maps, postgis_impervious_surface_map):
    impervious_surface_map = {
        "id": postgis_impervious_surface_map[0],
        "impervious_surface_id": postgis_impervious_surface_map[1],
        "connection_node_id": postgis_impervious_surface_map[2],
        "percentage": postgis_impervious_surface_map[3],
    }
    impervious_surface_maps.append(impervious_surface_map)
    return impervious_surface_maps


def add_1d_boundary_condition(onedee_boundaries, postgis_1d_boundary_condition):
    onedee_boundary_condition = {
        "id": postgis_1d_boundary_condition[0],
        "connection_node_id": postgis_1d_boundary_condition[1],
        "boundary_type": postgis_1d_boundary_condition[2],
        "timeseries": postgis_1d_boundary_condition[3],
    }
    onedee_boundaries.append(onedee_boundary_condition)
    return onedee_boundaries


def add_grid_refinement_area(grid_refinement_areas, postgis_grid_refinement_area):
    grid_refinement_area = {
        "id": postgis_grid_refinement_area[0],
        "display_name": postgis_grid_refinement_area[1],
        "refinement_level": postgis_grid_refinement_area[2],
        "code": postgis_grid_refinement_area[3],
        "the_geom": "srid={0};{1}".format(4326, postgis_grid_refinement_area[4]),
    }
    grid_refinement_areas.append(grid_refinement_area)
    return grid_refinement_areas


def add_grid_refinement(grid_refinements, postgis_grid_refinement):
    grid_refinement = {
        "id": postgis_grid_refinement[0],
        "display_name": postgis_grid_refinement[1],
        "refinement_level": postgis_grid_refinement[2],
        "code": postgis_grid_refinement[3],
        "the_geom": "srid={0};{1}".format(4326, postgis_grid_refinement[4]),
    }
    grid_refinements.append(grid_refinement)
    return grid_refinements


def add_surface_parameters(surface_parameters, postgis_surface_parameters):
    surface_parameter = {
        "id": postgis_surface_parameters[0],
        "outflow_delay": postgis_surface_parameters[1],
        "surface_layer_thickness": postgis_surface_parameters[2],
        "infiltration": postgis_surface_parameters[3],
        "max_infiltration_capacity": postgis_surface_parameters[4],
        "min_infiltration_capacity": postgis_surface_parameters[5],
        "infiltration_decay_constant": postgis_surface_parameters[6],
        "infiltration_recovery_constant": postgis_surface_parameters[7],
    }
    surface_parameters.append(surface_parameter)
    return surface_parameters


def add_surfaces(surfaces, postgis_surfaces):
    surface = {
        "id": postgis_surfaces[0],
        "display_name": postgis_surfaces[1],
        "code": postgis_surfaces[2],
        "zoom_category": postgis_surfaces[3],
        "nr_of_inhabitants": postgis_surfaces[4],
        "dry_weather_flow": postgis_surfaces[5],
        "function": postgis_surfaces[6],
        "area": postgis_surfaces[7],
        "surface_parameters_id": postgis_surfaces[8],
        "the_geom": "srid={0};{1}".format(4326, postgis_surfaces[9]),
    }
    surfaces.append(surface)
    return surfaces


def add_surface_maps(surface_maps, postgis_surface_map):
    surface = {
        "id": postgis_surface_map[0],
        "surface_type": postgis_surface_map[1],
        "surface_id": postgis_surface_map[2],
        "connection_node_id": postgis_surface_map[3],
        "percentage": postgis_surface_map[4],
    }
    surface_maps.append(surface)
    return surface_maps


def add_numerical_settings(numerical_settings, postgis_numerical_setting):
    numerical_setting = {
        "id": postgis_numerical_setting[0],
        "cfl_strictness_factor_1d": postgis_numerical_setting[1],
        "cfl_strictness_factor_2d": postgis_numerical_setting[2],
        "convergence_cg": postgis_numerical_setting[3],
        "convergence_eps": postgis_numerical_setting[4],
        "flow_direction_threshold": postgis_numerical_setting[5],
        "frict_shallow_water_correction": postgis_numerical_setting[6],
        "general_numerical_threshold": postgis_numerical_setting[7],
        "integration_method": postgis_numerical_setting[8],
        "limiter_grad_1d": postgis_numerical_setting[9],
        "limiter_grad_2d": postgis_numerical_setting[10],
        "limiter_slope_crossectional_area_2d": postgis_numerical_setting[11],
        "limiter_slope_friction_2d": postgis_numerical_setting[12],
        "max_nonlin_iterations": postgis_numerical_setting[13],
        "max_degree": postgis_numerical_setting[14],
        "minimum_friction_velocity": postgis_numerical_setting[15],
        "minimum_surface_area": postgis_numerical_setting[16],
        "precon_cg": postgis_numerical_setting[17],
        "preissmann_slot": postgis_numerical_setting[18],
        "pump_implicit_ratio": postgis_numerical_setting[19],
        "thin_water_layer_definition": postgis_numerical_setting[20],
        "use_of_cg": postgis_numerical_setting[21],
        "use_of_nested_newton": postgis_numerical_setting[22],
    }
    numerical_settings.append(numerical_setting)
    return numerical_settings


def add_global_settings(global_settings, postgis_global_setting):
    global_setting = {
        "id": postgis_global_setting[0],
        "use_2d_flow": postgis_global_setting[1],
        "use_1d_flow": postgis_global_setting[2],
        "manhole_storage_area": postgis_global_setting[3],
        "name": postgis_global_setting[4],
        "sim_time_step": postgis_global_setting[5],
        "output_time_step": postgis_global_setting[6],
        "nr_timesteps": postgis_global_setting[7],
        "start_time": postgis_global_setting[8],
        "start_date": postgis_global_setting[9],
        "grid_space": postgis_global_setting[10],
        "dist_calc_points": postgis_global_setting[11],
        "kmax": postgis_global_setting[12],
        "guess_dams": postgis_global_setting[13],
        "table_step_size": postgis_global_setting[14],
        "flooding_threshold": postgis_global_setting[15],
        "advection_1d": postgis_global_setting[16],
        "advection_2d": postgis_global_setting[17],
        "dem_file": postgis_global_setting[18],
        "frict_type": postgis_global_setting[19],
        "frict_coef": postgis_global_setting[20],
        "frict_coef_file": postgis_global_setting[21],
        "water_level_ini_type": postgis_global_setting[22],
        "initial_waterlevel": postgis_global_setting[23],
        "initial_waterlevel_file": postgis_global_setting[24],
        "interception_global": postgis_global_setting[25],
        "interception_file": postgis_global_setting[26],
        "dem_obstacle_detection": postgis_global_setting[27],
        "dem_obstacle_height": postgis_global_setting[28],
        "embedded_cutoff_threshold": postgis_global_setting[29],
        "epsg_code": postgis_global_setting[30],
        "timestep_plus": postgis_global_setting[31],
        "max_angle_1d_advection": postgis_global_setting[32],
        "minimum_sim_time_step": postgis_global_setting[33],
        "maximum_sim_time_step": postgis_global_setting[34],
        "frict_avg": postgis_global_setting[35],
        "wind_shielding_file": postgis_global_setting[36],
        "control_group_id": postgis_global_setting[37],
        "numerical_settings_id": postgis_global_setting[38],
        "use_0d_inflow": postgis_global_setting[39],
        "table_step_size_1d": postgis_global_setting[40],
        "table_step_size_volume_2d": postgis_global_setting[41],
        "use_2d_rain": postgis_global_setting[42],
        "initial_groundwater_level": postgis_global_setting[43],
        "initial_groundwater_level_file": postgis_global_setting[44],
        "initial_groundwater_level_type": postgis_global_setting[45],
        "groundwater_settings_id": postgis_global_setting[46],
        "simple_infiltration_settings_id": postgis_global_setting[47],
        "interflow_settings_id": postgis_global_setting[48],
    }
    global_settings.append(global_setting)
    return global_settings


def add_dem_average_area(dem_average_areas, postgis_dem_average_area):
    dem_average_area = {
        "id": postgis_dem_average_area[0],
        "the_geom": "srid={0};{1}".format(4326, postgis_dem_average_area[1]),
    }
    dem_average_areas.append(dem_average_area)
    return dem_average_areas


def add_windshielding(windshieldings, postgis_windshielding):
    windshielding = {
        "id": postgis_windshielding[0],
        "channel_id": postgis_windshielding[1],
        "north": postgis_windshielding[2],
        "northeast": postgis_windshielding[3],
        "east": postgis_windshielding[4],
        "southeast": postgis_windshielding[5],
        "south": postgis_windshielding[6],
        "southwest": postgis_windshielding[7],
        "west": postgis_windshielding[8],
        "northwest": postgis_windshielding[9],
        "the_geom": "srid={0};{1}".format(4326, postgis_windshielding[10]),
    }
    windshieldings.append(windshielding)
    return windshieldings


def add_2d_lateral(laterals_2d, postgis_lateral2d):
    lateral = {
        "id": postgis_lateral2d[0],
        "type": postgis_lateral2d[1],
        "the_geom": "srid={0};{1}".format(4326, postgis_lateral2d[2]),
        "timeseries": postgis_lateral2d[3],
    }
    laterals_2d.append(lateral)
    return laterals_2d


def add_1d_lateral(laterals_1d, postgis_lateral1d):
    lateral = {
        "id": postgis_lateral1d[0],
        "connection_node_id": postgis_lateral1d[1],
        "timeseries": postgis_lateral1d[2],
    }
    laterals_1d.append(lateral)
    return laterals_1d


def add_2d_boundary(boundary_conditions_2d, postgis_boundary2d):
    boundary_2d = {
        "id": postgis_boundary2d[0],
        "display_name": postgis_boundary2d[1],
        "timeseries": postgis_boundary2d[2],
        "boundary_type": postgis_boundary2d[3],
        "the_geom": "srid={0};{1}".format(4326, postgis_boundary2d[4]),
    }
    boundary_conditions_2d.append(boundary_2d)
    return boundary_conditions_2d


def add_groundwater(groundwaters, postgis_groundwater):
    groundwater = {
        "id": postgis_groundwater[0],
        "groundwater_impervious_layer_level": postgis_groundwater[1],
        "groundwater_impervious_layer_level_file": postgis_groundwater[2],
        "groundwater_impervious_layer_level_type": postgis_groundwater[3],
        "phreatic_storage_capacity": postgis_groundwater[4],
        "phreatic_storage_capacity_file": postgis_groundwater[5],
        "phreatic_storage_capacity_type": postgis_groundwater[6],
        "equilibrium_infiltration_rate": postgis_groundwater[7],
        "equilibrium_infiltration_rate_file": postgis_groundwater[8],
        "equilibrium_infiltration_rate_type": postgis_groundwater[9],
        "initial_infiltration_rate": postgis_groundwater[10],
        "initial_infiltration_rate_file": postgis_groundwater[11],
        "initial_infiltration_rate_type": postgis_groundwater[12],
        "infiltration_decay_period": postgis_groundwater[13],
        "infiltration_decay_period_file": postgis_groundwater[14],
        "infiltration_decay_period_type": postgis_groundwater[15],
        "groundwater_hydro_connectivity": postgis_groundwater[16],
        "groundwater_hydro_connectivity_file": postgis_groundwater[17],
        "groundwater_hydro_connectivity_type": postgis_groundwater[18],
        "display_name": postgis_groundwater[19],
        "leakage": postgis_groundwater[20],
        "leakage_file": postgis_groundwater[21],
    }
    groundwaters.append(groundwater)
    return groundwaters


def add_interflow(interflows, postgis_interflow):
    interflow = {
        "id": postgis_interflow[0],
        "interflow_type": postgis_interflow[1],
        "porosity": postgis_interflow[2],
        "porosity_file": postgis_interflow[3],
        "porosity_layer_thickness": postgis_interflow[4],
        "impervious_layer_elevation": postgis_interflow[5],
        "hydraulic_conductivity": postgis_interflow[6],
        "hydraulic_conductivity_file": postgis_interflow[7],
        "display_name": postgis_interflow[8],
    }
    interflows.append(interflow)
    return interflows


def add_aggregation_setting(aggregation_settings, postgis_aggregation_setting):
    aggregation_setting = {
        "id": postgis_aggregation_setting[0],
        "global_settings_id": postgis_aggregation_setting[1],
        "var_name": postgis_aggregation_setting[2],
        "flow_variable": postgis_aggregation_setting[3],
        "aggregation_method": postgis_aggregation_setting[4],
        "aggregation_in_space": postgis_aggregation_setting[5],
        "timestep": postgis_aggregation_setting[6],
    }
    aggregation_settings.append(aggregation_setting)
    return aggregation_settings


def add_simple_infiltration(simple_infiltrations, postgis_simple_infiltration):
    simple_infiltration = {
        "id": postgis_simple_infiltration[0],
        "infiltration_rate": postgis_simple_infiltration[1],
        "infiltration_rate_file": postgis_simple_infiltration[2],
        "infiltration_surface_option": postgis_simple_infiltration[3],
        "max_infiltration_capacity_file": postgis_simple_infiltration[4],
        "display_name": postgis_simple_infiltration[5],
    }
    simple_infiltrations.append(simple_infiltration)
    return simple_infiltrations


def add_control_group(control_groups, postgis_control_group):
    control_group = {
        "id": postgis_control_group[0],
        "name": postgis_control_group[1],
        "description": postgis_control_group[2],
    }
    control_groups.append(control_group)
    return control_groups


def add_control_measure_group(control_measure_groups, postgis_control_measure_group):
    control_measure_group = {
        "id": postgis_control_measure_group[0],
    }
    control_measure_groups.append(control_measure_group)
    return control_measure_groups


def add_control_measure_map(control_measure_maps, postgis_control_measure_map):
    control_measure_map = {
        "id": postgis_control_measure_map[0],
        "measure_group_id": postgis_control_measure_map[1],
        "object_type": postgis_control_measure_map[2],
        "object_id": postgis_control_measure_map[3],
        "weight": postgis_control_measure_map[4],
    }
    control_measure_maps.append(control_measure_map)
    return control_measure_maps


def add_control(controls, postgis_control):
    control = {
        "id": postgis_control[0],
        "control_group_id": postgis_control[1],
        "control_type": postgis_control[2],
        "control_id": postgis_control[3],
        "measure_group_id": postgis_control[4],
        "start": postgis_control[5],
        "end": postgis_control[6],
        "measure_frequency": postgis_control[7],
    }
    controls.append(control)
    return controls


def add_control_table(control_tables, postgis_control_table):
    control_table = {
        "id": postgis_control_table[0],
        "action_type": postgis_control_table[1],
        "measure_variable": postgis_control_table[2],
        "target_type": postgis_control_table[3],
        "target_id": postgis_control_table[4],
        "measure_operator": postgis_control_table[5],
        "action_table": postgis_control_table[6],
    }
    control_tables.append(control_table)
    return control_tables


def execute_sql_statement(sql_statement, fetch=True):
    """
    :param sql_statement: custom sql statement

    makes use of the existing database connection to run a custom query
    """

    conn = psycopg2.connect(
        host=config["db"]["hostname"],
        dbname=config["db"]["database"],
        user=config["db"]["username"],
        password=config["db"]["password"],
        port=config["db"]["port"],
    )

    with conn:
        with conn.cursor() as cur:
            cur.execute(sql_statement)
            if fetch is True:
                return cur.fetchall()


def main():
    try:
        return export_threedi(**vars(get_parser().parse_args()))
    except SystemExit:
        raise  # argparse does this


if __name__ == "__main__":
    main()

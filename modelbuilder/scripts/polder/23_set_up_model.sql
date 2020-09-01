-- Dit script maakt de scenarios in de spatialite en andere instellingen
-- Variabele <<polder_name>> wordt ingevuld
--NUMERICAL SETTINGS
INSERT INTO v2_numerical_settings
       ( id
            , integration_method
            , max_nonlin_iterations
            , convergence_eps
            , max_degree
            , use_of_cg
            , precon_cg
            , use_of_nested_newton
            , preissmann_slot
            , cfl_strictness_factor_1d
            , cfl_strictness_factor_2d
            , pump_implicit_ratio
            , frict_shallow_water_correction
            , limiter_slope_crossectional_area_2d
            , limiter_slope_friction_2d
            , limiter_grad_2d
            , limiter_grad_1d
            , flow_direction_threshold
            , minimum_friction_velocity
            , convergence_cg
            , general_numerical_threshold
            , minimum_surface_area
       )
       VALUES
       ( 1
            , --id
              0
            , --integration_method
              20
            , --max_nonlin_iterations
              1e-05
            , --convergence_eps
              7
            , --max_degree
              20
            , --use_of_cg
              1
            , --precon_cg
              1
            , --use_of_nested_newton
              0
            , --preissmann_slot
              NULL
            , --cfl_strictness_factor_1d
              NULL
            , --cfl_strictness_factor_2d
              1
            , --pump_implicit_ratio
              0
            , --frict_shallow_water_correction
              0
            , --limiter_slope_crossectional_area_2d
              0
            , --limiter_slope_friction_2d
              1
            , --limiter_grad_2d
              1
            , --limiter_grad_1d
              0.000001
            , --flow_direction_threshold
              0.05
            , --minimum_friction_velocity
              0.000000001
            , --convergence_cg
              0.00000001
            ,            --general_numerical_threshold
              0.00000001 --minimum_surface_area
       )
;

-- Simple infiltration
DELETE
FROM
       v2_simple_infiltration
;

INSERT INTO v2_simple_infiltration
       ( id
            , infiltration_rate
            , infiltration_rate_file
            , infiltration_surface_option
            , max_infiltration_capacity_file
            , display_name
       )
       VALUES
       ( 1
            , 0
            , 'rasters/infiltration_<<polder_name>>.tif'
            , --infiltration_rate_file
              NULL
            , 'rasters/storage_ghg_<<polder_name>>.tif'
            , --max_infiltration_capacity_file
              'ghg'
       )
     ,
        ( 2
            , 0
            , 'rasters/infiltration_<<polder_name>>.tif'
            , --infiltration_rate_file
              NULL
            , 'rasters/storage_ggg_<<polder_name>>.tif'
            , --max_infiltration_capacity_file
              'ggg'
       )
     ,
        ( 3
            , 0
            , 'rasters/infiltration_<<polder_name>>.tif'
            , --infiltration_rate_file
              NULL
            , 'rasters/storage_glg_<<polder_name>>.tif'
            , --max_infiltration_capacity_file
              'glg'
       )
;

--GLOBAL SETTINGS
DELETE
FROM
       v2_global_settings
;

-- 0d1D test
INSERT INTO v2_global_settings
       ( id
            , numerical_settings_id
            , use_0d_inflow
            , use_2d_flow
            , use_1d_flow
            , manhole_storage_area
            , name
            , use_2d_rain
            , control_group_id
            , sim_time_step
            , output_time_step
            , nr_timesteps
            , start_time
            , start_date
            , grid_space
            , kmax
            , dist_calc_points
            , table_step_size
            , flooding_threshold
            , advection_1d
            , advection_2d
            , dem_file
            , frict_type
            , frict_coef
            , frict_coef_file
            , water_level_ini_type
            , initial_waterlevel
            , initial_waterlevel_file
            ,
               --infiltration_rate,
               --infiltration_rate_file,
               --max_infiltration_capacity_file,
               --interflow_type,
               --hydraulic_conductivity,
               --hydraulic_conductivity_file,
               --porosity_layer_thickness,
               --porosity,
               --porosity_file,
               --impervious_layer_elevation,
               dem_obstacle_detection
            , dem_obstacle_height
            , embedded_cutoff_threshold
            , max_angle_1d_advection
            , epsg_code
            , timestep_plus
            , maximum_sim_time_step
            , minimum_sim_time_step
            ,
               --infiltration_surface_option,
               simple_infiltration_settings_id
            , frict_avg
       )
       VALUES
       ( 1
            , --id
              1
            , --numerical_settings_id
              1
            , --use_0d_inflow
              FALSE
            , --use_2d_flow
              TRUE
            , --use_1d_flow
              100
            , --manhole_storage_area
              '0d1d_test'
            , --name
              0
            , --use_2d_rain
              (
                     SELECT
                            max(id)
                     FROM
                            v2_control_group
              )
            , --control_group_id
              15
            , --sim_time_step
              900
            , --output_time_step
              999999
            , --nr_timesteps
              NULL
            , --start_time
              '2015-01-01'
            , --start_date
              20
            , --grid_space
              3
            , --kmax
              40
            , --dist_calc_points
              0.02
            , --table_step_size
              0.01
            , --flooding_threshold
              1
            , --advection_1d
              0
            , --advection_2d
              'rasters/dem_<<polder_name>>.tif'
            , --dem_file
              2
            , --frict_type
              0.026
            , --frict_coef
              NULL
            , --frict_coef_file
              NULL
            , --water_level_ini_type
              -99
            , --initial_waterlevel
              NULL
            , --initial_waterlevel_file
              --0,    --infiltration_rate
              --NULL,   --infiltration_rate_file
              --NULL,   --max_infiltration_capacity_file
              --0,    --interflow_type
              --NULL,   --hydraulic_conductivity
              --NULL,   --hydraulic_conductivity_file
              --NULL,   --porosity_layer_thickness
              --NULL,   --porosity
              --NULL,   --porosity_file
              --NULL,   --impervious_layer_elevation
              FALSE
            , --dem_obstacle_detection
              NULL
            , --dem_obstacle_height
              NULL
            , --embedded_cutoff_threshold
              NULL
            , --max_angle_1d_advection
              28992
            , --epsg_code
              TRUE
            , --timestep_plus
              300
            , --maximum_sim_time_step
              NULL
            , --minimum_sim_time_step
              --NULL,   --infiltration_surface_option
              NULL
            , 0 --frict_avg
       )
;

-- 1D2D maaiveld test
INSERT INTO v2_global_settings
       ( id
            , numerical_settings_id
            , use_0d_inflow
            , use_2d_flow
            , use_1d_flow
            , manhole_storage_area
            , name
            , use_2d_rain
            , control_group_id
            , sim_time_step
            , output_time_step
            , nr_timesteps
            , start_time
            , start_date
            , grid_space
            , kmax
            , dist_calc_points
            , table_step_size
            , flooding_threshold
            , advection_1d
            , advection_2d
            , dem_file
            , frict_type
            , frict_coef
            , frict_coef_file
            , water_level_ini_type
            , initial_waterlevel
            , initial_waterlevel_file
            ,
               --infiltration_rate,
               --infiltration_rate_file,
               --max_infiltration_capacity_file,
               --interflow_type,
               --hydraulic_conductivity,
               --hydraulic_conductivity_file,
               --porosity_layer_thickness,
               --porosity,
               --porosity_file,
               --impervious_layer_elevation,
               dem_obstacle_detection
            , dem_obstacle_height
            , embedded_cutoff_threshold
            , max_angle_1d_advection
            , epsg_code
            , timestep_plus
            , maximum_sim_time_step
            , minimum_sim_time_step
            ,
               --infiltration_surface_option,
               simple_infiltration_settings_id
            , frict_avg
       )
       VALUES
       ( 2
            , --id
              1
            , --numerical_settings_id
              0
            , --use_0d_inflow
              TRUE
            , --use_2d_flow
              TRUE
            , --use_1d_flow
              100
            , --manhole_storage_area
              '1d2d_test'
            , --name
              1
            , --use_2d_rain
              (
                     SELECT
                            max(id)
                     FROM
                            v2_control_group
              )
            , --control_group_id
              15
            , --sim_time_step
              900
            , --output_time_step
              999999
            , --nr_timesteps
              NULL
            , --start_time
              '2015-01-01'
            , --start_date
              20
            , --grid_space
              3
            , --kmax
              40
            , --dist_calc_points
              0.02
            , --table_step_size
              0.01
            , --flooding_threshold
              1
            , --advection_1d
              0
            , --advection_2d
              'rasters/dem_<<polder_name>>.tif'
            , --dem_file
              2
            , --frict_type
              0.026
            , --frict_coef
              'rasters/friction_<<polder_name>>.tif'
            , --frict_coef_file
              NULL
            , --water_level_ini_type
              -99
            , --initial_waterlevel
              NULL
            , --initial_waterlevel_file
              --0,    --infiltration_rate
              --NULL,   --infiltration_rate_file
              --NULL,   --max_infiltration_capacity_file
              --0,    --interflow_type
              --NULL,   --hydraulic_conductivity
              --NULL,   --hydraulic_conductivity_file
              --NULL,   --porosity_layer_thickness
              --NULL,   --porosity
              --NULL,   --porosity_file
              --NULL,   --impervious_layer_elevation
              FALSE
            , --dem_obstacle_detection
              NULL
            , --dem_obstacle_height
              NULL
            , --embedded_cutoff_threshold
              NULL
            , --max_angle_1d_advection
              28992
            , --epsg_code
              TRUE
            , --timestep_plus
              300
            , --maximum_sim_time_step
              NULL
            , --minimum_sim_time_step
              --NULL,   --infiltration_surface_option
              NULL
            , 0 --frict_avg
       )
;

-- 1D2D bodem GHG
INSERT INTO v2_global_settings
       ( id
            , numerical_settings_id
            , use_0d_inflow
            , use_2d_flow
            , use_1d_flow
            , manhole_storage_area
            , name
            , use_2d_rain
            , control_group_id
            , sim_time_step
            , output_time_step
            , nr_timesteps
            , start_time
            , start_date
            , grid_space
            , kmax
            , dist_calc_points
            , table_step_size
            , flooding_threshold
            , advection_1d
            , advection_2d
            , dem_file
            , frict_type
            , frict_coef
            , frict_coef_file
            , water_level_ini_type
            , initial_waterlevel
            , initial_waterlevel_file
            ,
               --infiltration_rate,
               --infiltration_rate_file,
               --max_infiltration_capacity_file,
               --interflow_type,
               --hydraulic_conductivity,
               --hydraulic_conductivity_file,
               --porosity_layer_thickness,
               --porosity,
               --porosity_file,
               --impervious_layer_elevation,
               dem_obstacle_detection
            , dem_obstacle_height
            , embedded_cutoff_threshold
            , max_angle_1d_advection
            , epsg_code
            , timestep_plus
            , maximum_sim_time_step
            , minimum_sim_time_step
            ,
               --infiltration_surface_option,
               simple_infiltration_settings_id
            , frict_avg
       )
       VALUES
       ( 3
            , --id
              1
            , --numerical_settings_id
              0
            , --use_0d_inflow
              TRUE
            , --use_2d_flow
              TRUE
            , --use_1d_flow
              100
            , --manhole_storage_area
              '1d2d_GHG'
            , --name
              1
            , --use_2d_rain
              (
                     SELECT
                            max(id)
                     FROM
                            v2_control_group
              )
            , --control_group_id
              15
            , --sim_time_step
              300
            , --output_time_step
              999999
            , --nr_timesteps
              NULL
            , --start_time
              '2015-01-01'
            , --start_date
              20
            , --grid_space
              3
            , --kmax
              40
            , --dist_calc_points
              0.02
            , --table_step_size
              0.01
            , --flooding_threshold
              1
            , --advection_1d
              0
            , --advection_2d
              'rasters/dem_<<polder_name>>.tif'
            , --dem_file
              2
            , --frict_type
              0.026
            , --frict_coef
              'rasters/friction_<<polder_name>>.tif'
            , --frict_coef_file
              NULL
            , --water_level_ini_type
              -99
            , --initial_waterlevel
              NULL
            , --initial_waterlevel_file
              --0,    --infiltration_rate
              --'rasters/infiltration_<<polder_name>>.tif',   --infiltration_rate_file
              --'rasters/storage_ghg_<<polder_name>>.tif',   --max_infiltration_capacity_file
              --0,    --interflow_type
              --NULL,   --hydraulic_conductivity
              --NULL,   --hydraulic_conductivity_file
              --NULL,   --porosity_layer_thickness
              --NULL,   --porosity
              --NULL,   --porosity_file
              --NULL,   --impervious_layer_elevation
              FALSE
            , --dem_obstacle_detection
              NULL
            , --dem_obstacle_height
              NULL
            , --embedded_cutoff_threshold
              NULL
            , --max_angle_1d_advection
              28992
            , --epsg_code
              TRUE
            , --timestep_plus
              300
            , --maximum_sim_time_step
              NULL
            , --minimum_sim_time_step
              --NULL,   --infiltration_surface_option
              1
            , 0 --frict_avg
       )
;

-- 1D2D bodem GG
INSERT INTO v2_global_settings
       ( id
            , numerical_settings_id
            , use_0d_inflow
            , use_2d_flow
            , use_1d_flow
            , manhole_storage_area
            , name
            , use_2d_rain
            , control_group_id
            , sim_time_step
            , output_time_step
            , nr_timesteps
            , start_time
            , start_date
            , grid_space
            , kmax
            , dist_calc_points
            , table_step_size
            , flooding_threshold
            , advection_1d
            , advection_2d
            , dem_file
            , frict_type
            , frict_coef
            , frict_coef_file
            , water_level_ini_type
            , initial_waterlevel
            , initial_waterlevel_file
            ,
               --infiltration_rate,
               --infiltration_rate_file,
               --max_infiltration_capacity_file,
               --interflow_type,
               --hydraulic_conductivity,
               --hydraulic_conductivity_file,
               --porosity_layer_thickness,
               --porosity,
               --porosity_file,
               --impervious_layer_elevation,
               dem_obstacle_detection
            , dem_obstacle_height
            , embedded_cutoff_threshold
            , max_angle_1d_advection
            , epsg_code
            , timestep_plus
            , maximum_sim_time_step
            , minimum_sim_time_step
            ,
               --infiltration_surface_option,
               simple_infiltration_settings_id
            , frict_avg
       )
       VALUES
       ( 4
            , --id
              1
            , --numerical_settings_id
              0
            , --use_0d_inflow
              TRUE
            , --use_2d_flow
              TRUE
            , --use_1d_flow
              100
            , --manhole_storage_area
              '1d2d_GGG'
            , --name
              1
            , --use_2d_rain
              (
                     SELECT
                            max(id)
                     FROM
                            v2_control_group
              )
            , --control_group_id
              15
            , --sim_time_step
              300
            , --output_time_step
              999999
            , --nr_timesteps
              NULL
            , --start_time
              '2015-01-01'
            , --start_date
              20
            , --grid_space
              3
            , --kmax
              40
            , --dist_calc_points
              0.02
            , --table_step_size
              0.01
            , --flooding_threshold
              1
            , --advection_1d
              0
            , --advection_2d
              'rasters/dem_<<polder_name>>.tif'
            , --dem_file
              2
            , --frict_type
              0.026
            , --frict_coef
              'rasters/friction_<<polder_name>>.tif'
            , --frict_coef_file
              NULL
            , --water_level_ini_type
              -99
            , --initial_waterlevel
              NULL
            , --initial_waterlevel_file
              --0,    --infiltration_rate
              --'rasters/infiltration_<<polder_name>>.tif',   --infiltration_rate_file
              --'rasters/storage_ggg_<<polder_name>>.tif',   --max_infiltration_capacity_file
              --0,    --interflow_type
              --NULL,   --hydraulic_conductivity
              --NULL,   --hydraulic_conductivity_file
              --NULL,   --porosity_layer_thickness
              --NULL,   --porosity
              --NULL,   --porosity_file
              --NULL,   --impervious_layer_elevation
              FALSE
            , --dem_obstacle_detection
              NULL
            , --dem_obstacle_height
              NULL
            , --embedded_cutoff_threshold
              NULL
            , --max_angle_1d_advection
              28992
            , --epsg_code
              TRUE
            , --timestep_plus
              300
            , --maximum_sim_time_step
              NULL
            , --minimum_sim_time_step
              --NULL,   --infiltration_surface_option
              2
            ,    --simple_infiltration_settings_id,
               0 --frict_avg
       )
;

-- 1D2D bodem GLG
INSERT INTO v2_global_settings
       ( id
            , numerical_settings_id
            , use_0d_inflow
            , use_2d_flow
            , use_1d_flow
            , manhole_storage_area
            , name
            , use_2d_rain
            , control_group_id
            , sim_time_step
            , output_time_step
            , nr_timesteps
            , start_time
            , start_date
            , grid_space
            , kmax
            , dist_calc_points
            , table_step_size
            , flooding_threshold
            , advection_1d
            , advection_2d
            , dem_file
            , frict_type
            , frict_coef
            , frict_coef_file
            , water_level_ini_type
            , initial_waterlevel
            , initial_waterlevel_file
            ,
               --infiltration_rate,
               --infiltration_rate_file,
               --max_infiltration_capacity_file,
               --interflow_type,
               --hydraulic_conductivity,
               --hydraulic_conductivity_file,
               --porosity_layer_thickness,
               --porosity,
               --porosity_file,
               --impervious_layer_elevation,
               dem_obstacle_detection
            , dem_obstacle_height
            , embedded_cutoff_threshold
            , max_angle_1d_advection
            , epsg_code
            , timestep_plus
            , maximum_sim_time_step
            , minimum_sim_time_step
            ,
               --infiltration_surface_option,
               simple_infiltration_settings_id
            , frict_avg
       )
       VALUES
       ( 5
            , --id
              1
            , --numerical_settings_id
              0
            , --use_0d_inflow
              TRUE
            , --use_2d_flow
              TRUE
            , --use_1d_flow
              100
            , --manhole_storage_area
              '1d2d_GLG'
            , --name
              1
            , --use_2d_rain
              (
                     SELECT
                            max(id)
                     FROM
                            v2_control_group
              )
            , --control_group_id
              15
            , --sim_time_step
              300
            , --output_time_step
              999999
            , --nr_timesteps
              NULL
            , --start_time
              '2015-01-01'
            , --start_date
              20
            , --grid_space
              3
            , --kmax
              40
            , --dist_calc_points
              0.02
            , --table_step_size
              0.01
            , --flooding_threshold
              1
            , --advection_1d
              0
            , --advection_2d
              'rasters/dem_<<polder_name>>.tif'
            , --dem_file
              2
            , --frict_type
              0.026
            , --frict_coef
              'rasters/friction_<<polder_name>>.tif'
            , --frict_coef_file
              NULL
            , --water_level_ini_type
              -99
            , --initial_waterlevel
              NULL
            , --initial_waterlevel_file
              --0,    --infiltration_rate
              --'rasters/infiltration_<<polder_name>>.tif',   --infiltration_rate_file
              --'rasters/storage_glg_<<polder_name>>.tif',   --max_infiltration_capacity_file
              --0,    --interflow_type
              --NULL,   --hydraulic_conductivity
              --NULL,   --hydraulic_conductivity_file
              --NULL,   --porosity_layer_thickness
              --NULL,   --porosity
              --NULL,   --porosity_file
              --NULL,   --impervious_layer_elevation
              FALSE
            , --dem_obstacle_detection
              NULL
            , --dem_obstacle_height
              NULL
            , --embedded_cutoff_threshold
              NULL
            , --max_angle_1d_advection
              28992
            , --epsg_code
              TRUE
            , --timestep_plus
              300
            , --maximum_sim_time_step
              --NULL,   --minimum_sim_time_step
              NULL
            , --infiltration_surface_option
              3
            , 0 --frict_avg
       )
;
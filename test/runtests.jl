using Test, RetentionData

db_path = joinpath(@__DIR__, "Databases", "Blumberg2017")
csv_paths = RetentionData.collect_csv_paths(db_path)
@test joinpath(db_path, "Blumberg2017_Parameters_TableS1a_SLB5ms_beta250.csv") in csv_paths
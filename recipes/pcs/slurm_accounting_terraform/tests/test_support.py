def openapi(*versions):
    paths = {}
    for version in versions:
        paths.update(
            {
                f"/slurm/{version}/ping": {"get": {}},
                f"/slurmdb/{version}/ping/": {"get": {}},
                f"/slurmdb/{version}/accounts": {"post": {}},
                f"/slurmdb/{version}/qos": {"post": {}},
                f"/slurmdb/{version}/users": {"post": {}},
                f"/slurmdb/{version}/wckeys": {"post": {}},
                f"/slurmdb/{version}/associations": {"post": {}},
            }
        )
    return {"paths": paths}

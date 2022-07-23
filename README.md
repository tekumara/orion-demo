# Orion Demo

Prefect Orion examples running self-contained in a local kubernetes cluster. Batteries (mostly) included. 🔋

## Getting started

Prerequisites:

- make
- node (required for pyright)
- python >= 3.9
- docker & docker-compose
- helm
- [k3d](https://k3d.io/) (for creating a local kubernetes cluster)
- kubectl

To start:

- Install the [development environment](CONTRIBUTING.md#Development-environment): `make install`

## Examples

Flows

- [Dask flow](flows/dask_flow.py) using a dask local cluster
- [Dask kubes flow](flows/dask_kubes_flow.py) using an ephemeral dask cluster on Kubernetes
- [Parameterized flow](flows/param_flow.py) using a custom Docker image containing additional modules
- [Ray flow](flows/ray_flow.py) that runs on an existing ray cluster (see [tekumara/ray-demo](https://github.com/tekumara/ray-demo))
- [Sub flow](flows/sub_flow.py) that is trigger by a parent flow

[Deployments](flows/kubes_deployments.py) to Kubernetes using

- the default OrionPackager to store the flow source in Orion
- the default OrionPackager to store the flow import path in Orion
- the FilePackager to store the flow source in S3 (minio)

## Usage

### Local

1. `make param-flow` or `make dask-flow` or `make ray-flow` or `make sub-flow`
1. `make ui` then navigate to [http://localhost:4200/](http://localhost:4200/)

The orion sqlite database is stored in _~/.prefect/orion.db_

### Kubernetes

Create k3d cluster with an image registry, minio (for remote storage), the prefect agent and api

```
make kubes
```

Create kubes deployments and run them

```
make kubes-deploy
```

### UI

Prefect UI: [http://localhost:4200/](http://localhost:4200/)

Minio UI: [http://localhost:9001](http://localhost:9001). User: `minioadmin` pass: `minioadmin`.

### API

Prefect API: [http://localhost:4200/api/](http://localhost:4200/api/)

## Docs

- [Blocks](blocks.md) - an overview and look into the database tables for Blocks.

## References

- [Orion tutorials](https://orion-docs.prefect.io/tutorials/first-steps/) from which some of the examples are taken

## Known limitations

- [Add mapping (.map() operator) #5582](https://githgsub.com/PrefectHQ/prefect/issues/5582)
- [Flow run parameters cannot be set in the UI #5617](https://github.com/PrefectHQ/prefect/issues/5617)
- [Logs configured in tasks with get_run_logger using DaskTaskRunner don't make it to the Prefect 2.0 backend #5850](https://github.com/PrefectHQ/prefect/issues/5850)
- Packagers only package the flow's source file, and not any modules it may reference. Referenced modules will need to be baked into the docker image.

## Caveats

The Deployment defines a flow name and the flow code. It's possible to have two Deployments with different flow code but the same flow name.

## Troubleshooting

### Flows are late

Check the logs of the agent:

```
make kube-logs
```

If you see `prefect.agent - No work queue found named 'kubernetes'` the work queue is missing. It can get lost when orion is restarted.

Recreate the work queue:

```
make kube-work-queue
```

And then your flows should start.

## Todo

- [Deployment yaml](https://orion-docs.prefect.io/concepts/deployments/#deployment-object) example
- Use service account in Kubes

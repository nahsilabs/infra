# infra

## CPU embeddings and ComfyUI

Qwen3-Embedding-0.6B uses TEI with the model baked into the image in
`containers/qwen3-embedding-tei`. Each replica requests 2 CPUs and 4 GiB RAM,
with limits of 2 CPUs and 6 GiB RAM. The HPA currently runs 1–3 replicas.
There is no hostname pin; Kubernetes selects a node using requests and taints.
Queries and ingestion share the same Service and have no reserved query capacity.

BGE-M3 remains in the retrieval catalog with zero replicas. Its Service, model
registration, and persistent cache remain available for reactivation.

ComfyUI requests 4 GiB RAM and has an 18 GiB limit. The request deliberately
under-reserves the measured cold image-edit workload, which used about 14 GiB
of anonymous memory. Scheduling another workload on the same node does not
guarantee enough memory for both at peak usage.

![Site Banner](docs/media/banner.png "The HPC Recipe Library - stand on the shoulders of... someone else.")

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.8360274.svg)](https://doi.org/10.5281/zenodo.8360274)
[![Static Badge](https://img.shields.io/badge/aws%20hpc%20blog-FF9900)](https://aws.amazon.com/blogs/hpc/introducing-a-community-recipe-library-for-hpc-infrastructure-on-aws/)

# HPC Recipes for AWS

This repository contains example recipes that demonstrate how to build HPC systems using [AWS Parallel Computing Service](https://aws.amazon.com/pcs/), [AWS ParallelCluster](https://aws.amazon.com/hpc/parallelcluster/), [Research and Engineering Studio](https://aws.amazon.com/hpc/res/), [AWS Batch](https://aws.amazon.com/batch/), and several other AWS products.

## Getting Started

* If you are new to AWS Parallel Computing Service (AWS PCS), you can watch this [short introductory video](https://youtu.be/BlgYbb6pdu0).
* You can learn about ParallelCluster from this [quick explainer video](https://youtu.be/gmw7A3kOh60).
* [This video](https://www.youtube.com/watch?v=2Nku6MWDwT0) introduces Research and Engineering Studio on AWS.
* Discover recipes to help you [get started with AWS PCS](recipes/pcs/)
* Try launching a HPC cluster in the cloud [with just a few clicks](recipes/pcs/getting_started/README.md).
* Need to set up HPC-ready networking? Choose from a [simple example](recipes/net/hpc_basic/README.md) or a [more advanced configuration](recipes/net/hpc_large_scale/README.md).
* There are also examples of setting up HPC-ready filesystems on AWS [for you to try and learn from](recipes/README.md#arrow_right-storage-storage).

If you just want to explore what all is available, the [recipes home page](./recipes/README.md) shows you every recipe. Here is an example of what you'll find:

![recipe](docs/media/recipe.png)

This recipe is named **byo_login**. It's part of the **pcs** (Parallel Computing Service) collection. Its tags tell us its a **core** recipe (i.e. maintained by AWS staff) and that it pertains to EC2, Lambda, and Secrets Manager as well as PCS. 

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## Contributing

We encourage your contributions to this collection. Read up on our [contribution process and guidelines](CONTRIBUTING.md). Then, head to **[Get Started](docs/start.md)** to begin. 

## License

This repository is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.


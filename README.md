# Unbound DNS for Docker

A small Unbound DNS image that can be used to start a DNS server.

## Supported tags

- `latest`

## What is Unbound DNS?

> Unbound is a validating, recursive, caching DNS resolver. It is designed to be fast and lean and incorporates modern features based on open standards.

*from* [nlnetlabs.nl](https://nlnetlabs.nl/projects/unbound/about/)

## Getting Started

There are a couple of things needed for the script to work.

### Prerequisites

Docker, either the Community Edition (CE) or Enterprise Edition (EE), needs to
be installed on your local computer.

#### Docker

Docker installation instructions can be found
[here](https://docs.docker.com/install/).

### Usage

In order to end up with a functional Unbound DNS service - after having build
the container - some configurations have to be performed.

To help perform those configurations a small set of commands is included on the
Docker container.

- `help` - Usage help.
- `init` - Configure the Unbound DNS service.
- `start` - Start the Unbound DNS service.

To store the configuration settings of the Unbound DNS server a volume should
be created and added to the container when running the same.

#### Creating Volumes

To be able to make all of the Unbound DNS configuration settings persistent,
the same will have to be stored on a different volume.

Creating volumes can be done using the `docker` tool. To create a volume use
the following command:

```shell
docker volume create --name VOLUME_NAME
```

Two create the required volume the following command can be used:

```shell
docker volume create --name my_unbound
```

**Note:** A local folder can also be used instead of a volume. Use the path of
the folder in place of the volume name.

#### Configuring the Unbound DNS Server

To configure the Unbound DNS server the `init` command must be used.

```shell
docker container run --volume UNBOUND_VOL:/data:rw --rm fscm/unbound [options] init
```

- `-s SLABS` - The number of slabs (must a power of two bellow the 'threads' value).
- `-t THREADS` - The number of threads.

After this step the Unbound DNS server should be configured and ready to be
used.

An example on how to configure the Unbound DNS server:

```shell
docker container run --volume my_unbound:/data:rw --rm fscm/unbound -s 1 -t 1 init
```

**Note:** All the configuration files will be created and placed on the Unbound
volume. You can mount that volume in your favorite Docker image and edit them
if needed. Local names can be created in the `local-zone.conf` file.

#### Start the Unbound DNS Server

After configuring the Unbound DNS server the same can now be started.

Starting the Unbound DNS server can be done with the `start` command.

```shell
docker container run --volume UNBOUND_VOL:/data:rw --detach --publish 53:53/udp fscm/unbound start
```

To help managing the container and the Unbound DNS instance a name can be
given to the container. To do this use the `--name <NAME>` docker option when
starting the server

An example on how the Unbound DNS service can be started:

```shell
docker container run --volume my_unbound:/data:rw --detach --publish 53:53/udp --name my_unbound fscm/unbound start
```

To see the output of the container that was started use the following command:

```shell
docker container attach CONTAINER_ID
```

Use the `ctrl+p` `ctrl+q` command sequence to detach from the container.

#### Stop the Unbound DNS Server

If needed the Unbound DNS server can be stoped and later started again (as
long as the command used to perform the initial start was as indicated before).

To stop the server use the following command:

```shell
docker container stop CONTAINER_ID
```

To start the server again use the following command:

```shell
docker container start CONTAINER_ID
```

### Unbound DNS Status

The Unbound DNS server status can be check in two ways.

The first way is by looking at the Unbound DNS server output data using the
docker command:

```shell
docker container logs CONTAINER_ID
```

The second way would be by looking at the Unbound DNS server status info. This
can be done with the **unbound-control** command:

```shell
docker container exec --interactive --tty CONTAINER_ID unbound-control status
```

## Build

Build instructions can be found
[here](https://github.com/fscm/docker-unbound/blob/master/README.build.md).

## Versioning

This project uses [SemVer](http://semver.org/) for versioning. For the versions
available, see the [tags on this repository](https://github.com/fscm/docker-unbound/tags).

## Authors

- **Frederico Martins** - [fscm](https://github.com/fscm)

See also the list of [contributors](https://github.com/fscm/docker-unbound/contributors)
who participated in this project.

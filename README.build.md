# Unbound DNS for Docker

Docker image with Unbound DNS.

## Synopsis

This script will create a Docker image with Unbound DNS installed and with all
of the required initialization scripts.

The Docker image resulting from this script should be the one used to
instantiate an Unbound DNS server.

## Getting Started

There are a couple of things needed for the script to work.

### Prerequisites

Docker, either the Community Edition (CE) or Enterprise Edition (EE), needs to
be installed on your local computer.

#### Docker

Docker installation instructions can be found
[here](https://docs.docker.com/install/).

### Usage

In order to create a Docker image using this Dockerfile you need to run the
`docker` command with a few options.

```
docker image build --force-rm --no-cache --quiet --tag <USER>/<IMAGE>:<TAG> <PATH>
```

* `<USER>` - *[required]* The user that will own the container image (e.g.: "johndoe").
* `<IMAGE>` - *[required]* The container name (e.g.: "unbound").
* `<TAG>` - *[required]* The container tag (e.g.: "latest").
* `<PATH>` - *[required]* The location of the Dockerfile folder.

A build example:

```
docker image build --force-rm --no-cache --quiet --tag johndoe/my_unbound:latest .
```

To clean any _<none>_ image(s) left by the build process the following
command can be used:

```
docker image rm `docker image ls --filter "dangling=true" --quiet`
```

You can also use the following command to achieve the same result:

```
docker image prune -f
```

### Instantiate a Container

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

```
docker volume create --name <VOLUME_NAME>
```

Two create the required volume the following command can be used:

```
docker volume create --name my_unbound
```

**Note:** A local folder can also be used instead of a volume. Use the path of
the folder in place of the volume name.

#### Configuring the Unbound Server

To configure the Unbound DNS server the `init` command must be used.

```
docker container run --volume <UNBOUND_VOL>:/data:rw --rm <USER>/<IMAGE>:<TAG> [options] init
```

* `-p <PORT>` - The server port (defaults to 53).
* `-s <SLABS>` - The number of slabs (must a power of two bellow the 'threads' value).
* `-t <THREADS>` - The number of threads.

After this step the Unbound DNS server should be configured and ready to be
used.

An example on how to configure the Unbound DNS server:

```
docker container run --volume my_unbound:/data:rw --rm johndoe/my_unbound -s 1 -t 1 init
```

**Note:** All the configuration files will be created and placed on the Unbound
volume. You can mount that volume in your favorite Docker image and edit them
if needed. Local names can be created in the `local-zone.conf` file.

#### Start the Unbound Server

After configuring the Unbound DNS server the same can now be started.

Starting the Unbound DNS server can be done with the `start` command.

```
docker container run --volume <UNBOUND_VOL>:/data:rw --detach --publish 53:53/udp <USER>/<IMAGE>:<TAG> start
```

To help managing the container and the Unbound DNS instance a name can be
given to the container. To do this use the `--name <NAME>` docker option when
starting the server

An example on how the Unbound DNS service can be started:

```
docker container --volume my_unbound:/data:rw --detach --publish 53:53/udp --name my_unbound johndoe/my_unbound start
```

To see the output of the container that was started use the following command:

```
docker container attach <CONTAINER_ID>
```

Use the `ctrl+p` `ctrl+q` command sequence to detach from the container.

#### Stop the Unbound Server

If needed the Unbound DNS server can be stoped and later started again (as
long as the command used to perform the initial start was as indicated before).

To stop the server use the following command:

```
docker container stop <CONTAINER_ID>
```

To start the server again use the following command:

```
docker container start <CONTAINER_ID>
```

### Unbound Status

The Unbound DNS server status can be check in two ways.

The first way is by looking at the Unbound DNS server output data using the
docker command:

```
docker container logs <CONTAINER_ID>
```

The second way would be by looking at the Unbound DNS server status info. This
can be done with the **unbound-control** command:

```
docker container exec --interactive --tty <CONTAINER_ID> unbound-control status
```

### Add Tags to the Docker Image

Additional tags can be added to the image using the following command:

```
docker image tag <image_id> <user>/<image>:<extra_tag>
```

### Push the image to Docker Hub

After adding an image to Docker, that image can be pushed to a Docker registry... Like Docker Hub.

Make sure that you are logged in to the service.

```
docker login
```

When logged in, an image can be pushed using the following command:

```
docker image push <user>/<image>:<tag>
```

Extra tags can also be pushed.

```
docker image push <user>/<image>:<extra_tag>
```

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request

Please read the [CONTRIBUTING.md](CONTRIBUTING.md) file for more details on how
to contribute to this project.

## Versioning

This project uses [SemVer](http://semver.org/) for versioning. For the versions
available, see the [tags on this repository](https://github.com/fscm/docker-unbound/tags).

## Authors

* **Frederico Martins** - [fscm](https://github.com/fscm)

See also the list of [contributors](https://github.com/fscm/docker-unbound/contributors)
who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE)
file for details

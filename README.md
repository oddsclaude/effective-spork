# image-template

This repository is meant to be a template for building your own custom [bootc](https://github.com/bootc-dev/bootc) image. This template is the recommended way to make customizations to any image published by the Universal Blue Project.

> [!NOTE]
> This repo's image build was migrated from a Containerfile/BlueBuild-style
> OCI build (`Containerfile.arch` + `build_files/`) to
> [mkosi](https://github.com/systemd/mkosi) (`mkosi.conf` +
> `mkosi.profiles/`), modeled on how
> [zirconium-dev/zirconium](https://github.com/zirconium-dev/zirconium) does
> it. The base distribution is still Arch Linux. `Containerfile.arch` is
> kept around for now since the `build-arch.yml` workflow's variant/flavor
> pipeline (`build-variant.yml` -> `reusable-build-image.yml`) still depends
> on it and wasn't touched as part of this migration -- see that workflow's
> comments / the migration PR description for details.

# Community

If you have questions about this template after following the instructions, try the following spaces:
- [Universal Blue Forums](https://universal-blue.discourse.group/)
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc discussion forums](https://github.com/bootc-dev/bootc/discussions) - This is not an Universal Blue managed space, but is an excellent resource if you run into issues with building bootc images.

# How to Use

To get started on your first bootc image, simply read and follow the steps in the next few headings.
If you prefer instructions in video form, TesterTech created an excellent tutorial, embedded below.

[![Video Tutorial](https://img.youtube.com/vi/IxBl11Zmq5w/0.jpg)](https://www.youtube.com/watch?v=IxBl11Zmq5wE)

## Step 0: Prerequisites

These steps assume you have the following:
- A Github Account
- A machine running a bootc image (e.g. Bazzite, Bluefin, Aurora, or Fedora Atomic)
- Experience installing and using CLI programs
- [mkosi](https://github.com/systemd/mkosi) and [just](https://just.systems/) installed locally if you want to build the image yourself

## Step 1: Preparing the Template

### Step 1a: Copying the Template

Select `Use this Template` on this page. You can set the name and description of your repository to whatever you would like, but all other settings should be left untouched.

Once you have finished copying the template, you need to enable the Github Actions workflows for your new repository.
To enable the workflows, go to the `Actions` tab of the new repository and click the button to enable workflows.

### Step 1b: Cloning the New Repository

Here I will defer to the much superior GitHub documentation on the matter. You can use whichever method is easiest.
[GitHub Documentation](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository)

Once you have the repository on your local drive, proceed to the next step.

## Step 2: Initial Setup

### Step 2a: Creating a Cosign Key

Container signing is important for end-user security and is enabled on all Universal Blue images. By default the image builds *will fail* if you don't.

First, install the [cosign CLI tool](https://edu.chainguard.dev/open-source/sigstore/cosign/how-to-install-cosign/#installing-cosign-with-the-cosign-binary)
With the cosign tool installed, run inside your repo folder:

```bash
COSIGN_PASSWORD="" cosign generate-key-pair
```

The signing key will be used in GitHub Actions and will not work if it is password protected.

> [!WARNING]
> Be careful to *never* accidentally commit `cosign.key` into your git repo. If this key goes out to the public, the security of your repository is compromised.

Next, you need to add the key to GitHub. This makes use of GitHub's secret signing system.

<details>
    <summary>Using the Github Web Interface (preferred)</summary>

Go to your repository settings, under `Secrets and Variables` -> `Actions`
![image](https://user-images.githubusercontent.com/1264109/216735595-0ecf1b66-b9ee-439e-87d7-c8cc43c2110a.png)
Add a new secret and name it `SIGNING_SECRET`, then paste the contents of `cosign.key` into the secret and save it. Make sure it's the .key file and not the .pub file. Once done, it should look like this:
![image](https://user-images.githubusercontent.com/1264109/216735690-2d19271f-cee2-45ac-a039-23e6a4c16b34.png)
</details>
<details>
<summary>Using the Github CLI</summary>

If you have the `github-cli` installed, run:

```bash
gh secret set SIGNING_SECRET < cosign.key
```
</details>

### Step 2b: Choosing Your Base Image

The base distribution is set in `mkosi.conf` under `[Distribution] Distribution=`. This repo builds on Arch Linux (`Distribution=arch`); package selection and build-time customization live in `mkosi.profiles/*/mkosi.conf` and the `mkosi.prepare.chroot`/`mkosi.postinst.chroot` scripts under each profile directory (see the "Repository Contents" section below).

If you want to switch base distributions entirely, mkosi supports several (`fedora`, `debian`, `ubuntu`, `opensuse`, etc. -- see [zirconium](https://github.com/zirconium-dev/zirconium) for a Fedora-based example of this same layout), but that's a bigger change than this migration covers.

### Step 2c: Changing Names

Change the `IMAGE_NAME` and `REPO_ORGANIZATION` variable inside the `image-template.env`

To commit and push all the files changed and added in step 2 into your Github repository:
```bash
git add mkosi.conf image-template.env cosign.pub
git commit -m "Initial Setup"
git push
```
Once pushed, go look at the Actions tab on your Github repository's page.  The green checkmark should be showing on the top commit, which means your new image is ready!

## Step 3: Switch to Your Image

From your bootc system, run the following command substituting in your Github username and image name where noted.
```bash
sudo bootc switch ghcr.io/<username>/<image_name>
```
This should queue your image for the next reboot, which you can do immediately after the command finishes. You have officially set up your custom image! See the following section for an explanation of the important parts of the template for customization.

# Repository Contents

## mkosi.conf / mkosi.profiles

[`mkosi.conf`](./mkosi.conf) is the top-level mkosi configuration: it sets the base distribution (`Distribution=arch`), output format, and shared build settings. It's intentionally minimal -- almost everything else lives in [`mkosi.profiles/`](./mkosi.profiles), one directory per profile:

- `base/` -- core packages every build needs (kernel, ostree, systemd, networking, etc.)
- `hyprland/` -- the Hyprland desktop flavor's packages and postinst setup
- `nvidia/` -- optional NVIDIA driver stack, opt-in via the `nvidia` profile
- `brew/` -- fetches and installs the ublue-os Homebrew tarball
- `bootc/` -- builds `bootc`/`bootupd` from source (Arch doesn't package them yet) and wires up the dracut `bootc` module
- `cachy/` -- **experimental/unverified**, opt-in CachyOS kernel profile

Profiles are combined at build time (see `just build` in the Justfile below). Each profile directory can contain its own `mkosi.conf` (for `Packages=` and other settings), `mkosi.prepare.chroot` (runs after packages install, **with** network access -- for fetching/building things from source), and `mkosi.postinst.chroot` (runs after that, **without** network access -- for installing what prepare fetched/built and doing final setup). The top-level [`mkosi.finalize.chroot`](./mkosi.finalize.chroot) always runs and sets up the ostree/bootc directory layout (pacman state relocation, `/var` symlinks, etc.) regardless of which profiles are selected.

[`mkosi.extra/`](./mkosi.extra) mirrors what `system_files/` used to do: anything under it gets copied verbatim into the image at `/`.

## build.yml

The [build.yml](./.github/workflows/build.yml) Github Actions workflow builds the image with mkosi, loads it into podman, rechunks it, and publishes it to the Github Container Registry (GHCR). By default, the image name will match the Github repository name.

# Building Disk Images

This template provides an out of the box workflow for creating disk images (ISO, qcow, raw) for your custom OCI image which can be used to directly install onto your machines.

This part of the pipeline is unchanged by the mkosi migration: it still consumes the already-built, already-tagged local image via [bootc-image-builder](https://osbuild.org/docs/bootc/) (`bib`), same as before -- run `just build && just load` first, then the `build-qcow2`/`build-iso` recipes below.

This template provides a way to upload the disk images that is generated from the workflow to a S3 bucket. The disk images will also be available as an artifact from the job, if you wish to use an alternate provider. To upload to S3 we use [rclone](https://rclone.org/) which is able to use [many S3 providers](https://rclone.org/s3/).

## Setting Up ISO Builds

The [build-disk.yml](./.github/workflows/build-disk.yml) Github Actions workflow creates a disk image from your OCI image by utilizing the [bootc-image-builder](https://osbuild.org/docs/bootc/). In order to use this workflow you must complete the following steps:

1. Modify `disk_config/iso.toml` to point to your custom container image before generating an ISO image.
2. If you changed your image name from the default in `build.yml` then in the `build-disk.yml` file edit the `IMAGE_REGISTRY`, `IMAGE_NAME` and `DEFAULT_TAG` environment variables with the correct values. If you did not make changes, skip this step.
3. Finally, if you want to upload your disk images to S3 then you will need to add your S3 configuration to the repository's Action secrets. This can be found by going to your repository settings, under `Secrets and Variables` -> `Actions`. You will need to add the following
  - `S3_PROVIDER` - Must match one of the values from the [supported list](https://rclone.org/s3/)
  - `S3_BUCKET_NAME` - Your unique bucket name
  - `S3_ACCESS_KEY_ID` - It is recommended that you make a separate key just for this workflow
  - `S3_SECRET_ACCESS_KEY` - See above.
  - `S3_REGION` - The region your bucket lives in. If you do not know then set this value to `auto`.
  - `S3_ENDPOINT` - This value will be specific to the bucket as well.

Once the workflow is done, you'll find the disk images either in your S3 bucket or as part of the summary under `Artifacts` after the workflow is completed.

# Artifacthub

This template comes with the necessary tooling to index your image on [artifacthub.io](https://artifacthub.io). Use the `artifacthub-repo.yml` file at the root to verify yourself as the publisher. This is important to you for a few reasons:

- The value of artifacthub is it's one place for people to index their custom images, and since we depend on each other to learn, it helps grow the community. 
- You get to see your pet project listed with the other cool projects in Cloud Native.
- Since the site puts your README front and center, it's a good way to learn how to write a good README, learn some marketing, finding your audience, etc. 

[Discussion Thread](https://universal-blue.discourse.group/t/listing-your-custom-image-on-artifacthub/6446)

# Justfile Documentation

The `Justfile` contains various commands and configurations for building and managing container images and virtual machine images using mkosi, Podman, and other utilities. It is also used inside Github Actions.

## Required Utilities

Container build:
- [just](https://just.systems/man/en/introduction.html)
- [mkosi](https://github.com/systemd/mkosi)
- [podman](https://docs.podman.io/en/latest)
- [jq])(https://jqlang.org)

Linting:
- shfmt
- shellcheck

## Environment Variables

These are all sourced from the `image-template.env` file.

- `image_name`: The name of the image (default: "image-template").
- `default_tag`: The default tag for the image (default: "latest").
- `bib_image`: The Bootc Image Builder (BIB) image (default: "quay.io/centos-bootc/bootc-image-builder:latest").

Additionally, `ENABLE_NVIDIA=1` and `ENABLE_CACHYOS=1` (experimental) can be set in the environment to opt the `just build` recipe into the corresponding mkosi profiles.

## Building The Image

### `just build`

Builds the OCI image with mkosi, using the `base,hyprland,bootc,brew` profiles (plus `nvidia`/`cachy` if enabled via the environment variables above).

```bash
just build
```

### `just load`

Loads the most recently built mkosi output into local podman storage, tagged `$target_image:$tag`. Run this after `just build`.

```bash
just load $target_image $tag
```

### `just lint-image`

Runs `bootc container lint` against the loaded image.

```bash
just lint-image $target_image $tag
```

### Rechunking
We can flatten the layers of container images to make sure there isn't a single huge layer when your image gets published.
This does not make your image faster to download, just provides better resumability.

#### `just rechunk`
Rechunks the loaded image with [chunkah](https://github.com/coreos/chunkah). This step is unchanged by the mkosi migration -- chunkah works on any OCI image regardless of how it was built.

```bash
just rechunk $target_image $tag
```

### Switching to the locally built image for testing

The image has to be in the containers-storage owned by root, to be able to rebase to it.

You can rebase to all the images that are in your containers-storage:

```
sudo podman image list --filter=label=containers.bootc=1
```

See [man bootc switch](https://bootc.dev/bootc/man/bootc-switch.8.html) for more info.

```
sudo bootc switch --transport containers-storage localhost/myimage:latest
```

and reboot your system!

## Building and Running Virtual Machines and ISOs

The below commands all build QCOW2 images. To produce or use a different type of image, substitute in the command with that type in the place of `qcow2`. The available types are `qcow2`, `iso`, and `raw`. These still go through `just build && just load` first, then bootc-image-builder, same as before the mkosi migration.

### `just build-qcow2`

Builds a QCOW2 virtual machine image.

```bash
just build-qcow2 $target_image $tag
```

### `just rebuild-qcow2`

Rebuilds a QCOW2 virtual machine image.

```bash
just rebuild-vm $target_image $tag
```

### `just run-vm-qcow2`

Runs a virtual machine from a QCOW2 image.

```bash
just run-vm-qcow2 $target_image $tag
```

### `just spawn-vm`

Runs a virtual machine using systemd-vmspawn.

```bash
just spawn-vm rebuild="0" type="qcow2" ram="6G"
```

## File Management

### `just check`

Checks the syntax of all `.just` files and the `Justfile`.

### `just fix`

Fixes the syntax of all `.just` files and the `Justfile`.

### `just clean`

Cleans the repository by removing build artifacts (including `mkosi clean`).

### `just lint`

Runs shell check on all Bash scripts.

### `just format`

Runs shfmt on all Bash scripts.

## Additional resources

For additional driver support, ublue maintains a set of scripts and container images available at [ublue-akmod](https://github.com/ublue-os/akmods). These images include the necessary scripts to install multiple kernel drivers within the container (Nvidia, OpenRazer, Framework...). The documentation provides guidance on how to properly integrate these drivers into your container image.

## Community Examples

These are images derived from this template (or similar enough to this template). Reference them when building your image!

- [m2Giles' OS](https://github.com/m2giles/m2os)
- [bOS](https://github.com/bsherman/bos)
- [Homer](https://github.com/bketelsen/homer/)
- [Amy OS](https://github.com/astrovm/amyos)
- [VeneOS](https://github.com/Venefilyn/veneos)
- [Zirconium](https://github.com/zirconium-dev/zirconium) -- the mkosi layout this migration was modeled on (Fedora-based, not Arch)

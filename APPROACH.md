## My approach to creating docker images for dedicated game servers

Why not use someone else's image, why create your own? Because I want to do it in a specific way and I can. Some people will like my approach (I certainly do), some won't. It's wonderful when there is choice.

A lot of opinion goes below, you've been warned.

### Do not use a custom image as the base image for `Dockerfile`

I use operating system base images in the `Dockerfile`, not custom images, so it's easy to see what's in there at a glance. If you create images for many games, you might want to put steam and wine in a base image and use that. For the short `Dockerfile`s like this one I prefer to keep everything in a single place because it's easier to change in one place. I usually only have time to work on one image at a time, so it is unlikely I will need to make the same change for several images.

### Do not attempt to copy the entire server configuration to env variables

Some images try to expose every setting in the game configuration files through an environment variable. I do not see a lot of value in that. Editing a game config file is as simple as editing `docker-compose.yaml`, at the same time synchronizing gradual settings change as game develops between the config file and environment variable seems like a wasted effort to me.

There are two cases where I think it's warranted to use environment variables in the discussed context:

- When you need a vital configuration without which the first run of your docker container is impossible
- You need to expose a setting that is not available from the game configs (e.g. you implement modding support)

### Care about start up time

I've seen containers that pull dependencies on each start up, where it's not really required and just adds to the startup time. I prefer to keep those in the base image. At the same time there is a lot of value in updating the game on startup, the check usually is reasonably quick, but updating also means we do not need to create a new image each time the developers release a new game version, so I think this is a reasonable compromise.

### Allow container re-creation without data loss

There is nothing more frustrating than executing `docker compose down` to realize that your settings/saves/progress have been lost forever. Docker images should either use `VOLUME` to persist that data or document which paths should be mapped with `docker` or `docker compose` to make sure that the container can be deleted, re-created and continue running where it left off.

### Support graceful termination if possible

In the realm of steam games running on wine, this is quite tricky. Still where possible doing `docker compose stop` or `docker compose down` should execute graceful termination that might allow the server to save the state before shutting down. In some games the server also cleans up a multiplayer session that otherwise needs to expire on its own before the server could start again.

### Simplicity over "maintainability", where practical

Do not use `EXPOSE` - this is for "documentation" purposes only, but I usually provide documentation with the image - the user does not have to look up `EXPOSE` in the `Dockerfile`, this information is available with the rest of the documentation.

Do not create variables and don't try to make things "reusable" if you have only three files under 40 lines each. Search and replace works well if you need to change several spots, and having the actual value on the line you are reading is usually more helpful than needing to look up where the variable was set.

_Note: I'm obviously not against variables, programming would be impossible without them, but for the context of such tiny projects readability is more important for easier maintenance_


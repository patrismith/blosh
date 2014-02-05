# Blo.sh
## A bash blog engine
### v 0.1.0

I wrote this to learn bash. It's a very simple program -- all it does update files. It's pretty fragile and will probably break if:

* The folder hierarchy is missing essential folders
* A template file is missing
* And many more!

Additionally, there is no real RSS or Javascript support, and no comments.

It definitely works for my purposes and perhaps you will get something out of it too.

## Usage

**blo.sh** requires **rsync** and **markdown**.

Run `./blo.sh -i` to create the proper folder hierarchy. Or, you can clone this project and start editing.

The folder hierarchy is as follows:

*   draft - this is where you put files you'd like to include on your blog.
*   draft/images - place images here. Currently only 'supporting' png due to an idiosyncracity of my blog engine + rsync that I haven't figured out.
*   draft/css - place css here.
*   draft/blog - contains blog posts, in markdown format.
*   draft/index - contains static pages, in markdown format.
*   draft/templates - templates go here. These are used in conjunction with the blog posts and static pages to create html files.
*   live - this is the constructed website. It contains html generated from draft/index, and css files.
*   live/images - all images reside here.
*   live/blog - all blog posts reside here.

Run `./blo.sh -u` to update the contents of `live` with the contents of `draft`.

Run `./blo.sh -h` to see the other commands blosh accepts. (There's not many.)

Warning: New pages and page/image/css updates are handled by the script, but page/image/css deletion needs to be done by hand.

## Tutorial

1. Prepare a folder on your computer named "my-blog" and make it your current working directory.

2. `git clone` this repository.

3. You should now see a file `blo.sh` and two directories, `draft` and `live`. Fire up your favorite editor and type whatever's on your mind. Use markdown format if you feel like it. Save the results to `draft/blog/first-post.md`.

4. Run `./blo.sh -uv`.

5. Run a small http server (such as SimpleHTTPServer) from `live`. Navigate to its root in your web browser. You should see something like the below:

![Screenshot of tutorial webpage](https://raw2.github.com/patrismith/blosh/master/screenshot.png)

6. Create more posts and save them to `draft/blog/`. You should give them small names like `my-post.md` or `this-is-cool.md`, and don't use spaces or underscores in the name, just hyphens.

7. Run `./blo.sh -uv` again.

8. Reload the page in your web browser. You should see the last post you made as your site's index.

9. Click the "history" link. You should see a list in reverse chronological order of all the blog posts you made!

## License

Copyright (c) 2014 P Smith

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

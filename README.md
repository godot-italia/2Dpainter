2Dpainter (alpha version 0.1.0)
===
This is a Godot Engine plugin to "scatter paint" Sprites in a scene 2D released under MIT licence by Dario De Vita
All the images attached in the example scene are owned by the author and released free to use for any purpouse.

How to use
===
The plugin isn't ready yet therefore it is not in the AssetLib yet. It should be cloned and tested:

- Clone the repository
- Add all the file in the "addons" folder to your Godot 2D project in `res://addons`
- Go to Project -> Project settings -> Plugin tab and activate the plugin
- Add the custom node `Painter` to the scene in whatever node that inherits from `Node2D`
- (if the plugin is active) a new dock panel will appear an the left dock when the `Painter` node is selected
- select a folder containing .jpg or .png from the folder select
- select/deselect the images you would like to paint from the panel
- click on the "paint" button to start painting the selected sprites. Left click to add Sprites, right click to remove them, scroll wheel to select the next sprite

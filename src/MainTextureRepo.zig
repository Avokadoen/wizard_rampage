const rl = @import("raylib");

const GameTextureRepo = @This();

button: [6]rl.Texture,

pub fn init() !GameTextureRepo {
    var button: [6]rl.Texture = undefined;
    const which_button_info = @typeInfo(which_button);
    var textures_loaded: u32 = 0;
    errdefer {
        for (button[0..textures_loaded]) |texture| {
            rl.unloadTexture(texture);
        }
    }
    inline for (which_button_info.@"enum".fields, &button) |which_texture, *texture| {
        texture.* = try rl.loadTexture("resources/textures/main_menu/buttons/" ++ which_texture.name ++ ".png");
        textures_loaded += 1;
    }

    return GameTextureRepo{
        .button = button,
    };
}

pub fn deinit(self: GameTextureRepo) void {
    inline for (self.button) |texture| {
        texture.unload();
    }
}

pub const texture_type = enum {
    buttons,
};

pub const which_button = enum {
    Exit_Active,
    Exit_Idle,
    Options_Active,
    Options_Idle,
    Start_Active,
    Start_Idle,
};

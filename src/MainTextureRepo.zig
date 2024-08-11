const rl = @import("raylib");

const GameTextureRepo = @This();

button: [6]rl.Texture,

pub fn init() GameTextureRepo {
    var button: [6]rl.Texture = undefined;
    const which_button_info = @typeInfo(which_button);
    inline for (which_button_info.Enum.fields, &button) |which_texture, *texture| {
        texture.* = rl.loadTexture("resources/textures/main_menu/buttons/" ++ which_texture.name ++ ".png");
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

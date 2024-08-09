const rl = @import("raylib");

const TextureRepo = @This();

textures: [72]rl.Texture,

pub fn init() TextureRepo {
    var textures: [72]rl.Texture = undefined;
    const which_info = @typeInfo(which);
    inline for (which_info.Enum.fields, &textures) |which_texture, *texture| {
        texture.* = rl.loadTexture("resources/textures/player/" ++ which_texture.name ++ ".png");
    }

    return TextureRepo{
        .textures = textures,
    };
}

pub fn deinit(self: TextureRepo) void {
    inline for (self.textures) |texture| {
        texture.unload();
    }
}

pub const which = enum {
    Cloak0001,
    Cloak0002,
    Cloak0003,
    Cloak0004,
    Cloak0005,
    Cloak0006,
    Cloak0007,
    Cloak0008,
    Gem_Cast0001,
    Gem_Cast0002,
    Gem_Cast0003,
    Gem_Cast0004,
    Gem_Cast0005,
    Gem_Cast0006,
    Gem_Cast0007,
    Gem_Cast0008,
    Gem0001,
    Gem0002,
    Gem0003,
    Gem0004,
    Gem0005,
    Gem0006,
    Gem0007,
    Gem0008,
    Hand_L0001,
    Hand_L0002,
    Hand_L0003,
    Hand_L0004,
    Hand_L0005,
    Hand_L0006,
    Hand_L0007,
    Hand_L0008,
    Hand_R0001,
    Hand_R0002,
    Hand_R0003,
    Hand_R0004,
    Hand_R0005,
    Hand_R0006,
    Hand_R0007,
    Hand_R0008,
    Hat0001,
    Hat0002,
    Hat0003,
    Hat0004,
    Hat0005,
    Hat0006,
    Hat0007,
    Hat0008,
    Head0001,
    Head0002,
    Head0003,
    Head0004,
    Head0005,
    Head0006,
    Head0007,
    Head0008,
    Staff_Cast0001,
    Staff_Cast0002,
    Staff_Cast0003,
    Staff_Cast0004,
    Staff_Cast0005,
    Staff_Cast0006,
    Staff_Cast0007,
    Staff_Cast0008,
    Staff0001,
    Staff0002,
    Staff0003,
    Staff0004,
    Staff0005,
    Staff0006,
    Staff0007,
    Staff0008,
};

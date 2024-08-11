const rl = @import("raylib");

const GameSoundRepo = @This();

effects: [@typeInfo(which_effects).Enum.fields.len]rl.Sound,

pub fn init() GameSoundRepo {
    const enum_fields = @typeInfo(which_effects).Enum.fields;
    var effects: [enum_fields.len]rl.Sound = undefined;
    inline for (enum_fields, &effects) |which_texture, *sound| {
        sound.* = rl.loadSound("resources/sounds/effects/" ++ which_texture.name ++ ".wav");
    }

    return GameSoundRepo{
        .effects = effects,
    };
}

pub fn deinit(self: GameSoundRepo) void {
    inline for (self.effects) |sound| {
        rl.unloadSound(sound);
    }
}

pub const which_effects = enum {
    Enemy_Attack,
    Kill,
    Player_Damage_01,
    Player_Damage_02,
    Player_Damage_03,
    Spell_01,
    Splatter_01,
    Splatter_02,
    Splatter_03,
};

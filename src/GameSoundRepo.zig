const rl = @import("raylib");

const GameSoundRepo = @This();

effects: [@typeInfo(which_effects).@"enum".fields.len]rl.Sound,

pub fn init() !GameSoundRepo {
    const enum_fields = @typeInfo(which_effects).@"enum".fields;
    var effects: [enum_fields.len]rl.Sound = undefined;
    var loaded_effects: u32 = 0;
    errdefer {
        for (effects[0..loaded_effects]) |effect| {
            rl.unloadSound(effect);
        }
    }
    inline for (enum_fields, &effects) |which_texture, *sound| {
        sound.* = try rl.loadSound("resources/sounds/effects/" ++ which_texture.name ++ ".wav");
        loaded_effects += 1;
    }

    inline for ([_]NormalizeEffect{
        .{ .which = .Player_Damage_02, .new_volume = 0.4 },
        .{ .which = .Player_Damage_03, .new_volume = 0.4 },
    }) |normalize| {
        const sound = effects[@intFromEnum(normalize.which)];
        rl.setSoundVolume(sound, normalize.new_volume);
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

const NormalizeEffect = struct {
    which: which_effects,
    new_volume: f32,
};

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

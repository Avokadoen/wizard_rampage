const rl = @import("raylib");

const GameTextureRepo = @This();

player: [@typeInfo(which_player).@"enum".fields.len]rl.Texture,
projectile: [@typeInfo(which_projectile).@"enum".fields.len]rl.Texture,
farmer: [@typeInfo(which_farmer).@"enum".fields.len]rl.Texture,
blood_splatter: [@typeInfo(which_bloodsplat).@"enum".fields.len]rl.Texture,
country: [@typeInfo(which_country_side).@"enum".fields.len]rl.Texture,
inventory: [@typeInfo(which_inventory).@"enum".fields.len]rl.Texture,
decor: [@typeInfo(which_decor).@"enum".fields.len]rl.Texture,
wife: [@typeInfo(which_wife).@"enum".fields.len]rl.Texture,
cauldron: [@typeInfo(which_cauldron).@"enum".fields.len]rl.Texture,

pub fn init() !GameTextureRepo {
    @setEvalBranchQuota(10_000);

    const player = try loadTextureGroup(which_player, "resources/textures/player/");
    errdefer {
        inline for (player) |texture| {
            texture.unload();
        }
    }

    const projectile = try loadTextureGroup(which_projectile, "resources/textures/projectiles/");
    errdefer {
        inline for (projectile) |texture| {
            texture.unload();
        }
    }

    const farmer = try loadTextureGroup(which_farmer, "resources/textures/farmer/");
    errdefer {
        inline for (farmer) |texture| {
            texture.unload();
        }
    }

    const blood_splatter = try loadTextureGroup(which_bloodsplat, "resources/textures/effects/bloodsplat/");
    errdefer {
        inline for (blood_splatter) |texture| {
            texture.unload();
        }
    }

    const country = try loadTextureGroup(which_country_side, "resources/textures/country_side/");
    errdefer {
        inline for (country) |texture| {
            texture.unload();
        }
    }

    const inventory = try loadTextureGroup(which_inventory, "resources/textures/inventory/");
    errdefer {
        inline for (inventory) |texture| {
            texture.unload();
        }
    }

    const decor = try loadTextureGroup(which_decor, "resources/textures/decor/");
    errdefer {
        inline for (decor) |texture| {
            texture.unload();
        }
    }

    const wife = try loadTextureGroup(which_wife, "resources/textures/boss_wife/");
    errdefer {
        inline for (wife) |texture| {
            texture.unload();
        }
    }

    const cauldron = try loadTextureGroup(which_cauldron, "resources/textures/player/cauldron/");
    errdefer {
        inline for (cauldron) |texture| {
            texture.unload();
        }
    }

    return GameTextureRepo{
        .player = player,
        .projectile = projectile,
        .farmer = farmer,
        .blood_splatter = blood_splatter,
        .country = country,
        .inventory = inventory,
        .decor = decor,
        .wife = wife,
        .cauldron = cauldron,
    };
}

pub fn deinit(self: GameTextureRepo) void {
    // TODO: use reflection for this
    inline for (self.player) |texture| {
        texture.unload();
    }
    inline for (self.projectile) |texture| {
        texture.unload();
    }
    inline for (self.farmer) |texture| {
        texture.unload();
    }
    inline for (self.blood_splatter) |texture| {
        texture.unload();
    }
    inline for (self.country) |texture| {
        texture.unload();
    }
    inline for (self.inventory) |texture| {
        texture.unload();
    }
    inline for (self.decor) |texture| {
        texture.unload();
    }
    inline for (self.wife) |texture| {
        texture.unload();
    }
    inline for (self.cauldron) |texture| {
        texture.unload();
    }
}

fn loadTextureGroup(comptime TextureEnum: type, comptime texture_group_path: []const u8) ![@typeInfo(TextureEnum).@"enum".fields.len]rl.Texture {
    const enum_fields = @typeInfo(TextureEnum).@"enum".fields;

    var textures: [enum_fields.len]rl.Texture = undefined;
    var textures_loaded: u32 = 0;
    errdefer {
        for (textures[0..textures_loaded]) |texture| {
            rl.unloadTexture(texture);
        }
    }

    inline for (enum_fields, &textures) |which_texture, *texture| {
        texture.* = try rl.loadTexture(texture_group_path ++ which_texture.name ++ ".png");
        textures_loaded += 1;
    }

    return textures;
}

pub const texture_type = enum {
    player,
    projectile,
    farmer,
    blood_splatter,
    country,
    inventory,
    decor,
    wife,
    cauldron,
};

pub const which_player = enum {
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
pub const which_projectile = enum {
    Bolt_01,
    Bolt_02,
    Bolt_03,
    Bolt_04,
    Bolt_05,
    Red_Gem_01,
    Red_Gem_02,
    Red_Gem_03,
    Red_Gem_04,
    Red_Gem_05,
    Red_Gem_06,
    Red_Gem_07,
    Red_Gem_08,
    Red_Gem_09,
    Red_Gem_10,
};
pub const which_farmer = enum {
    Farmer_Body0001,
    Farmer_Body0002,
    Farmer_Body0003,
    Farmer_Body0004,
    Farmer_Body0005,
    Farmer_Body0006,
    Farmer_Body0007,
    Farmer_Body0008,
    Farmer_Hand_L0001,
    Farmer_Hand_L0002,
    Farmer_Hand_L0003,
    Farmer_Hand_L0004,
    Farmer_Hand_L0005,
    Farmer_Hand_L0006,
    Farmer_Hand_L0007,
    Farmer_Hand_L0008,
    Farmer_Hand_R0001,
    Farmer_Hand_R0002,
    Farmer_Hand_R0003,
    Farmer_Hand_R0004,
    Farmer_Hand_R0005,
    Farmer_Hand_R0006,
    Farmer_Hand_R0007,
    Farmer_Hand_R0008,
    Farmer_Hat0001,
    Farmer_Hat0002,
    Farmer_Hat0003,
    Farmer_Hat0004,
    Farmer_Hat0005,
    Farmer_Hat0006,
    Farmer_Hat0007,
    Farmer_Hat0008,
    Farmer_Head0001,
    Farmer_Head0002,
    Farmer_Head0003,
    Farmer_Head0004,
    Farmer_Head0005,
    Farmer_Head0006,
    Farmer_Head0007,
    Farmer_Head0008,
    Farmer_Pitchfork0001,
    Farmer_Pitchfork0002,
    Farmer_Pitchfork0003,
    Farmer_Pitchfork0004,
    Farmer_Pitchfork0005,
    Farmer_Pitchfork0006,
    Farmer_Pitchfork0007,
    Farmer_Pitchfork0008,
};
pub const which_bloodsplat = enum {
    Blood_Splat,
    Blood_Splat0001,
    Blood_Splat0002,
    Blood_Splat0003,
    Blood_Splat0004,
    Blood_Splat0005,
    Blood_Splat0006,
    Blood_Splat0007,
    Blood_Splat0008,
};
pub const which_country_side = enum {
    Dirt,
    Fence_Horizontal,
    Fence_Vertical,
    Grass,
    Mushroom,
    Tree,
};

pub const which_inventory = enum {
    Damage_Amp_Modifier,
    Yellow_Gem,
    Gem_Slot_Staff_Background,
    Piercing_Modifier,
    Red_Gem,
    Slot,
    Slot_Cursor,
    Gem_Bag,
};

pub const which_decor = enum {
    Daisies,
    Rocks,
};

pub const which_wife = enum {
    Wife_Idle_Body0001,
    Wife_Idle_Body0002,
    Wife_Idle_Body0003,
    Wife_Idle_Body0004,
    Wife_Idle_Body0005,
    Wife_Idle_Body0006,
    Wife_Idle_Body0007,
    Wife_Idle_Body0008,
    Wife_Idle_Hand_L0001,
    Wife_Idle_Hand_L0002,
    Wife_Idle_Hand_L0003,
    Wife_Idle_Hand_L0004,
    Wife_Idle_Hand_L0005,
    Wife_Idle_Hand_L0006,
    Wife_Idle_Hand_L0007,
    Wife_Idle_Hand_L0008,
    Wife_Idle_Hand_R0001,
    Wife_Idle_Hand_R0002,
    Wife_Idle_Hand_R0003,
    Wife_Idle_Hand_R0004,
    Wife_Idle_Hand_R0005,
    Wife_Idle_Hand_R0006,
    Wife_Idle_Hand_R0007,
    Wife_Idle_Hand_R0008,
    Wife_Idle_Head0001,
    Wife_Idle_Head0002,
    Wife_Idle_Head0003,
    Wife_Idle_Head0004,
    Wife_Idle_Head0005,
    Wife_Idle_Head0006,
    Wife_Idle_Head0007,
    Wife_Idle_Head0008,
};

pub const which_cauldron = enum {
    HP_Blood,
    HP_Cauldron,
    HP_Mask,
};

module suigar::math {
    public fun pow(base: u64, exponent: u8) : u64 {
        let current_base = base;
        let remaining_exp = exponent;
        let result = 1;
        while (remaining_exp >= 1) {
            if (remaining_exp % 2 == 0) {
                current_base = current_base * current_base;
                remaining_exp = remaining_exp / 2;
                continue
            };
            result = result * current_base;
            remaining_exp = remaining_exp - 1;
        };
        result
    }
}
/*

replicated dist bug?

    // ************************
    // BUG: by having an array of objects it causes Chapel to use N-1 CPUs at 100%
    // ************************
    // // use an array of DocumentIdPoolBankSubPool so that we don't have to allocate everything up front
    // var documentIdPool: [0..3] DocumentIdPoolBank = [
    //   new DocumentIdPoolBank(1 << 1, 1 << 23), // 2 + 2 + 1 + 27 = 32 = 2 + 2 + 1 + 23 + 4
    //   new DocumentIdPoolBank(1 << 4, 1 << 20), // 2 + 2 + 4 + 24 = 32 = 2 + 2 + 4 + 20 + 4
    //   new DocumentIdPoolBank(1 << 7, 1 << 17), // 2 + 2 + 7 + 21 = 32 = 2 + 2 + 4 + 17 + 4
    //   new DocumentIdPoolBank(1 << 11, 1 << 13) // 2 + 2 + 11 + 17 = 32 = 2 + 2 + 4 + 13 + 4
    // ];


*/
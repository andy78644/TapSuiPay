#[test_only]
module tapsuipay_move::tapsuipay_move_tests {
    // 引入必要的模組
    use std::string::{Self, String};
    use sui::test_scenario::{Self, Scenario, ctx, sender, next_tx, take_shared, return_shared, end, has_most_recent_for_address, take_from_address, return_to_address};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::test_utils::{assert_eq};
    use tapsuipay_move::tapsuipay::{Self, MerchantRegistry, AdminCap};

    // 測試地址常量
    const ADMIN: address = @0x1;
    const MERCHANT1: address = @0x42;
    const MERCHANT2: address = @0x43;
    const USER1: address = @0x100;
    const USER2: address = @0x101;

    // 初始化測試場景
    fun scenario(): Scenario {
        let mut scenario = test_scenario::begin(ADMIN);
        tapsuipay::test_init(ctx(&mut scenario));
        next_tx(&mut scenario, ADMIN);
        scenario
    }

    // 測試初始化功能
    #[test]
    fun test_initialization() {
        let mut scenario = scenario();
        
        // 驗證初始化是否成功，管理員是否獲得 AdminCap
        next_tx(&mut scenario, ADMIN);
        {
            assert!(has_most_recent_for_address<AdminCap>(ADMIN), 0);
        };
        
        end(scenario);
    }

    // 測試商家註冊功能
    #[test]
    fun test_merchant_registration() {
        let mut scenario = scenario();
        
        // 商家註冊
        next_tx(&mut scenario, MERCHANT1);
        {
            let mut registry = take_shared<MerchantRegistry>(&scenario);
            let merchant_name = b"TestShop";
            
            tapsuipay::register_merchant(&mut registry, merchant_name, ctx(&mut scenario));
            
            // 驗證商家是否成功註冊
            assert!(tapsuipay::merchant_exists(&registry, merchant_name), 0);
            
            // 驗證商家地址是否正確
            let merchant_address = tapsuipay::get_merchant_address(&registry, merchant_name);
            assert_eq(merchant_address, MERCHANT1);
            
            return_shared(registry);
        };
        
        end(scenario);
    }

    // 測試更新商家地址功能
    #[test]
    fun test_update_merchant_address() {
        let mut scenario = scenario();
        
        // 先註冊商家
        next_tx(&mut scenario, MERCHANT1);
        {
            let mut registry = take_shared<MerchantRegistry>(&scenario);
            let merchant_name = b"UpdateTest";
            
            tapsuipay::register_merchant(&mut registry, merchant_name, ctx(&mut scenario));
            return_shared(registry);
        };
        
        // 更新商家地址
        next_tx(&mut scenario, MERCHANT1);
        {
            let mut registry = take_shared<MerchantRegistry>(&scenario);
            let merchant_name = b"UpdateTest";
            let new_address = MERCHANT2;
            
            tapsuipay::update_merchant_address(
                &mut registry, 
                merchant_name, 
                new_address, 
                ctx(&mut scenario)
            );
            
            // 驗證地址是否成功更新
            let merchant_address = tapsuipay::get_merchant_address(&registry, merchant_name);
            assert_eq(merchant_address, new_address);
            
            return_shared(registry);
        };
        
        end(scenario);
    }

    // 測試用戶支付功能
    #[test]
    fun test_purchase() {
        let mut scenario = scenario();
        
        // 先註冊商家
        next_tx(&mut scenario, MERCHANT1);
        {
            let mut registry = take_shared<MerchantRegistry>(&scenario);
            let merchant_name = b"PaymentTest";
            
            tapsuipay::register_merchant(&mut registry, merchant_name, ctx(&mut scenario));
            return_shared(registry);
        };
        
        // 創建代幣並進行支付
        next_tx(&mut scenario, USER1);
        {
            let mut registry = take_shared<MerchantRegistry>(&scenario);
            let merchant_name = b"PaymentTest";
            let product_info = b"Test Product 1";
            let payment_amount = 100000000; // 0.1 SUI
            
            // 創建 SUI 代幣用於支付
            let payment = coin::mint_for_testing<SUI>(payment_amount, ctx(&mut scenario));
            
            // 獲取商家初始餘額
            let mut merchant_initial_balance = 0;
            if (has_most_recent_for_address<Coin<SUI>>(MERCHANT1)) {
                let coin = take_from_address<Coin<SUI>>(&scenario, MERCHANT1);
                merchant_initial_balance = coin::value(&coin);
                return_to_address(MERCHANT1, coin);
            };
            
            // 進行支付
            tapsuipay::purchase(
                &mut registry, 
                merchant_name,
                product_info,
                payment,
                ctx(&mut scenario)
            );
            
            // 驗證商家的餘額是否增加
            let mut merchant_new_balance = 0;
            if (has_most_recent_for_address<Coin<SUI>>(MERCHANT1)) {
                let coin = take_from_address<Coin<SUI>>(&scenario, MERCHANT1);
                merchant_new_balance = coin::value(&coin);
                return_to_address(MERCHANT1, coin);
            };
            assert_eq(merchant_new_balance, merchant_initial_balance + payment_amount);
            
            return_shared(registry);
        };
        
        end(scenario);
    }

    // // 測試管理員移除商家功能
    // #[test]
    // fun test_admin_remove_merchant() {
    //     let mut scenario = setup_test();
        
    //     // 註冊商家
    //     next_tx(&mut scenario, MERCHANT1);
    //     {
    //         let registry = take_shared<MerchantRegistry>(&scenario);
    //         let merchant_name = b"RemoveTest";
            
    //         tapsuipay_move::register_merchant(&mut registry, merchant_name, ctx(&mut scenario));
    //         return_shared(registry);
    //     };
        
    //     // 管理員移除商家
    //     next_tx(&mut scenario, ADMIN);
    //     {
    //         let mut registry = take_shared<MerchantRegistry>(&scenario);
    //         let admin_cap = take_from_address<AdminCap>(&scenario, ADMIN);
    //         let merchant_name = b"RemoveTest";
            
    //         // 驗證商家存在
    //         assert!(tapsuipay_move::merchant_exists(&registry, merchant_name), 0);
            
    //         // 管理員移除商家
    //         tapsuipay_move::admin_remove_merchant(&admin_cap, &mut registry, merchant_name);
            
    //         // 驗證商家已被移除
    //         assert!(!tapsuipay_move::merchant_exists(&registry, merchant_name), 0);
            
    //         return_to_address(ADMIN, admin_cap);
    //         return_shared(registry);
    //     };
        
    //     end(scenario);
    // }

    // // 測試商家名稱錯誤情況
    // #[test]
    // #[expected_failure(abort_code = tapsuipay_move::tapsuipay_move::EInvalidMerchantName)]
    // fun test_invalid_merchant_name_short() {
    //     let mut scenario = setup_test();
        
    //     next_tx(&mut scenario, MERCHANT1);
    //     {
    //         let mut registry = take_shared<MerchantRegistry>(&scenario);
    //         let merchant_name = b"AB"; // 名稱太短 (最小長度為3)
            
    //         tapsuipay_move::register_merchant(&mut registry, merchant_name, ctx(&mut scenario));
            
    //         return_shared(registry);
    //     };
        
    //     end(scenario);
    // }

    // // 測試商家名稱重複註冊
    // #[test]
    // #[expected_failure(abort_code = tapsuipay_move::tapsuipay_move::EMerchantNameTaken)]
    // fun test_duplicate_merchant_name() {
    //     let mut scenario = setup_test();
        
    //     // 第一次註冊
    //     next_tx(&mut scenario, MERCHANT1);
    //     {
    //         let mut registry = take_shared<MerchantRegistry>(&scenario);
    //         let merchant_name = b"DuplicateTest";
            
    //         tapsuipay_move::register_merchant(&mut registry, merchant_name, ctx(&mut scenario));
    //         return_shared(registry);
    //     };
        
    //     // 重複註冊同一個名稱
    //     next_tx(&mut scenario, MERCHANT2);
    //     {
    //         let mut registry = take_shared<MerchantRegistry>(&scenario);
    //         let merchant_name = b"DuplicateTest";
            
    //         // 這裡應該失敗，因為名稱已被使用
    //         tapsuipay_move::register_merchant(&mut registry, merchant_name, ctx(&mut scenario));
            
    //         return_shared(registry);
    //     };
        
    //     end(scenario);
    // }

    // // 測試非商家擁有者嘗試更新地址
    // #[test]
    // #[expected_failure(abort_code = tapsuipay_move::tapsuipay_move::ENotMerchantOwner)]
    // fun test_unauthorized_update() {
    //     let mut scenario = setup_test();
        
    //     // 先註冊商家
    //     next_tx(&mut scenario, MERCHANT1);
    //     {
    //         let registry = take_shared<MerchantRegistry>(&scenario);
    //         let merchant_name = b"AuthTest";
            
    //         tapsuipay_move::register_merchant(&mut registry, merchant_name, ctx(&mut scenario));
    //         return_shared(registry);
    //     };
        
    //     // 另一個用戶嘗試更新商家地址
    //     next_tx(&mut scenario, MERCHANT2); // 非商家擁有者
    //     {
    //         let mut registry = take_shared<MerchantRegistry>(&scenario);
    //         let merchant_name = b"AuthTest";
    //         let new_address = MERCHANT2;
            
    //         // 這裡應該失敗，因為 MERCHANT2 不是商家擁有者
    //         tapsuipay_move::update_merchant_address(
    //             &mut registry, 
    //             merchant_name, 
    //             new_address, 
    //             ctx(&mut scenario)
    //         );
            
    //         return_shared(registry);
    //     };
        
    //     end(scenario);
    // }

    // // 測試支付不存在的商家
    // #[test]
    // #[expected_failure(abort_code = tapsuipay_move::tapsuipay_move::EMerchantNotExists)]
    // fun test_pay_nonexistent_merchant() {
    //     let mut scenario = setup_test();
        
    //     next_tx(&mut scenario, USER1);
    //     {
    //         let mut registry = take_shared<MerchantRegistry>(&scenario);
    //         let merchant_name = b"NonExistentShop";
    //         let product_info = b"Test Product";
    //         let payment_amount = 100000000; // 0.1 SUI
            
    //         // 創建 SUI 代幣用於支付
    //         let payment = coin::mint_for_testing<SUI>(payment_amount, ctx(&mut scenario));
            
    //         // 嘗試向不存在的商家支付
    //         tapsuipay_move::purchase(
    //             &mut registry, 
    //             merchant_name, 
    //             product_info, 
    //             payment, 
    //             ctx(&mut scenario)
    //         );
            
    //         return_shared(registry);
    //     };
        
    //     end(scenario);
    // }
}
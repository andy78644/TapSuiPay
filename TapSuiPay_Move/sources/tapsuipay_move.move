// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions

module tapsuipay_move::tapsuipay {
    // 引入必要的模組，移除不必要的別名
    use std::string::{Self, String};
    use sui::table::{Self, Table};
    use sui::coin;
    use sui::sui::SUI;
    use sui::event;
    use sui::package;
    use sui::display;
    
    // 錯誤碼
    const EMerchantNotExists: u64 = 1;
    const EMerchantNameTaken: u64 = 2;
    const ENotMerchantOwner: u64 = 3;
    const EInvalidMerchantName: u64 = 5;
    const EInvalidProductInfo: u64 = 6;
    const EInvalidAmount: u64 = 7;

    // 常量定义
    const MIN_MERCHANT_NAME_LENGTH: u64 = 3;
    const MAX_MERCHANT_NAME_LENGTH: u64 = 50;
    const MAX_PRODUCT_INFO_LENGTH: u64 = 200;
    const MIN_PAYMENT_AMOUNT: u64 = 1;

    // 商家結構
    public struct Merchant has store, copy, drop {
        name: String,
        address: address,
    }

    // 商家註冊表，用於存儲所有註冊的商家
    public struct MerchantRegistry has key {
        id: UID,
        merchants: Table<String, Merchant>,
    }

    // 管理員能力，用於初始化和管理平台
    public struct AdminCap has key, store {
        id: UID,
    }

    // One-Time-Witness 結構，必須標記為 public
    public struct TAPSUIPAY has drop {}

    // 初始化標記，用於確保只初始化一次
    public struct InitCap has key {
        id: UID
    }

    // 事件
    public struct MerchantRegistered has copy, drop {
        name: String,
        address: address
    }

    public struct PaymentSent has copy, drop {
        from: address,
        to: address,
        amount: u64,
        merchant_name: String,
        product_info: String
    }

    #[lint_allow(self_transfer, share_owned)]
    fun init(otw: TAPSUIPAY, ctx: &mut TxContext) {
        // 如果已經初始化過，這個操作將失敗（因為共享對象唯一性）
        let init_cap = InitCap {
            id: sui::object::new(ctx)
        };
        sui::transfer::share_object(init_cap);
        
        // 創建商家註冊表
        let registry = MerchantRegistry {
            id: object::new(ctx),
            merchants: table::new(ctx),
        };

        // 創建管理員權限
        let admin_cap = AdminCap {
            id: sui::object::new(ctx),
        };

        // 轉移註冊表到共享對象，讓所有用戶可以訪問
        sui::transfer::share_object(registry);
        
        // 轉移管理員權限給發送者（合約部署者）
        sui::transfer::public_transfer(admin_cap, sui::tx_context::sender(ctx));

        // 設置合約基本資訊顯示
        let publisher = package::claim(otw, ctx);
        
        // 使用簡化的方式創建 display 對象
        let mut display_obj = display::new<MerchantRegistry>(&publisher, ctx);
        display::add(&mut display_obj, string::utf8(b"name"), string::utf8(b"TapSuiPay - 第三方支付平台"));
        display::add(&mut display_obj, string::utf8(b"description"), string::utf8(b"提供商家註冊和用戶支付服務的去中心化平台"));
        
        // 確保版本更新且傳輸
        display::update_version(&mut display_obj);
        
        // 轉移 publisher 和 display_obj 給合約部署者
        // 使用公開轉移
        sui::transfer::public_transfer(publisher, sui::tx_context::sender(ctx));
        sui::transfer::public_transfer(display_obj, sui::tx_context::sender(ctx));
    }

    // 商家註冊函數
    public entry fun register_merchant(
        registry: &mut MerchantRegistry,
        name: vector<u8>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let merchant_name = string::utf8(name);
        let sender = sui::tx_context::sender(ctx);

        // 驗證商家名稱長度
        let name_length = string::length(&merchant_name);
        assert!(name_length >= MIN_MERCHANT_NAME_LENGTH && name_length <= MAX_MERCHANT_NAME_LENGTH, EInvalidMerchantName);

        // 檢查商家名稱是否已被註冊
        assert!(!table::contains(&registry.merchants, merchant_name), EMerchantNameTaken);

        // 創建新商家並添加到註冊表
        let merchant = Merchant {
            name: merchant_name,
            address: sender,
        };
        table::add(&mut registry.merchants, merchant_name, merchant);

        // 發出商家註冊事件
        event::emit(MerchantRegistered {
            name: merchant_name,
            address: sender
        });
    }

    // 更新商家地址
    public entry fun update_merchant_address(
        registry: &mut MerchantRegistry,
        name: vector<u8>,
        new_address: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let merchant_name = string::utf8(name);
        let sender = sui::tx_context::sender(ctx);

        // 檢查商家是否存在
        assert!(table::contains(&registry.merchants, merchant_name), EMerchantNotExists);
        
        let merchant = table::borrow(&registry.merchants, merchant_name);
        
        // 確保只有商家本人可以更新地址
        assert!(merchant.address == sender, ENotMerchantOwner);

        // 更新商家地址
        let updated_merchant = Merchant {
            name: merchant_name,
            address: new_address,
        };
        table::remove(&mut registry.merchants, merchant_name);
        table::add(&mut registry.merchants, merchant_name, updated_merchant);
    }

    // 用戶付款函數
    public entry fun purchase(
        registry: &mut MerchantRegistry,
        merchant_name: vector<u8>,
        product_info: vector<u8>,
        payment: coin::Coin<SUI>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let merchant_name_str = string::utf8(merchant_name);
        let product_info_str = string::utf8(product_info);
        
        // 檢查商家是否存在
        assert!(table::contains(&registry.merchants, merchant_name_str), EMerchantNotExists);
        
        // 驗證產品信息長度
        assert!(string::length(&product_info_str) <= MAX_PRODUCT_INFO_LENGTH, EInvalidProductInfo);
        
        // 獲取商家地址
        let merchant = table::borrow(&registry.merchants, merchant_name_str);
        let merchant_address = merchant.address;
        
        // 檢查支付金額
        let amount = coin::value(&payment);
        assert!(amount >= MIN_PAYMENT_AMOUNT, EInvalidAmount);
        
        // 將資金轉移給商家
        sui::transfer::public_transfer(payment, merchant_address);
        
        // 發出支付事件
        event::emit(PaymentSent {
            from: sui::tx_context::sender(ctx),
            to: merchant_address,
            amount,
            merchant_name: merchant_name_str,
            product_info: product_info_str
        });
    }

    // 公開查詢函數 - 獲取商家地址
    public fun get_merchant_address(
        registry: &MerchantRegistry,
        name: vector<u8>
    ): address {
        let merchant_name = string::utf8(name);
        
        // 檢查商家是否存在
        assert!(table::contains(&registry.merchants, merchant_name), EMerchantNotExists);
        
        // 返回商家地址
        let merchant = table::borrow(&registry.merchants, merchant_name);
        merchant.address
    }

    // 公開查詢函數 - 檢查商家是否存在
    public fun merchant_exists(
        registry: &MerchantRegistry,
        name: vector<u8>
    ): bool {
        let merchant_name = string::utf8(name);
        table::contains(&registry.merchants, merchant_name)
    }

    // 管理員功能 - 強制移除商家 (未來可能需要用於處理惡意商家)
    public entry fun admin_remove_merchant(
        _: &AdminCap,
        registry: &mut MerchantRegistry,
        name: vector<u8>,
    ) {
        let merchant_name = string::utf8(name);
        
        // 檢查商家是否存在
        assert!(table::contains(&registry.merchants, merchant_name), EMerchantNotExists);
        
        // 移除商家
        table::remove(&mut registry.merchants, merchant_name);
    }

    // 測試用初始化函數
    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        let registry = MerchantRegistry {
            id: sui::object::new(ctx),
            merchants: table::new(ctx),
        };

        let admin_cap = AdminCap {
            id: sui::object::new(ctx),
        };

        sui::transfer::share_object(registry);
        
        // 使用固定地址而非發送者
        let admin_address = @0x1;
        sui::transfer::public_transfer(admin_cap, admin_address);
    }
}



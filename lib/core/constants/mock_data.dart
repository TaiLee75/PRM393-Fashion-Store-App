// Dữ liệu mẫu (Seed Data) chuẩn Enterprise cho cửa hàng thời trang Fashion Store
// Dùng để nạp tự động lên Firebase Firestore qua nút bấm "Seed Data" trên ShopAdminScreen

final List<Map<String, dynamic>> mockCategories = [
  {
    "id": "cat_aothun",
    "name": "Áo Thun & Polo",
    "iconUrl": "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=300",
  },
  {
    "id": "cat_aokhoac",
    "name": "Áo Khoác & Hoodie",
    "iconUrl": "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=300",
  },
  {
    "id": "cat_quanjean",
    "name": "Quần Jean & Kaki",
    "iconUrl": "https://images.unsplash.com/photo-1542272604-780c96856592?w=300",
  },
  {
    "id": "cat_phukien",
    "name": "Phụ Kiện Thời Trang",
    "iconUrl": "https://images.unsplash.com/photo-1588850561407-ed78c282e89b?w=300",
  },
];

final List<Map<String, dynamic>> mockProducts = [
  // 1. Áo Polo Pique Cotton
  {
    "id": "prod_001",
    "name": "Áo Polo Nam Form Regular Pique",
    "categoryId": "cat_aothun",
    "price": 289000,
    "originalPrice": 350000,
    "description": "Chất liệu 95% Cotton chải kỹ, 5% Spandex co giãn 4 chiều. Bo cổ dệt tinh tế, chống bai dão khi giặt máy.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1586363104862-3a5e2ab60d99?w=800",
      "https://images.unsplash.com/photo-1625910513413-56272517036a?w=800",
    ],
    "sizes": ["S", "M", "L", "XL"],
    "colors": ["Đen", "Trắng", "Xanh navy"],
    "stock": 133,
    "variantStock": {
      "S_Đen": 15,
      "M_Đen": 20,
      "L_Đen": 12,
      "XL_Đen": 8,
      "S_Trắng": 10,
      "M_Trắng": 18,
      "L_Trắng": 10,
      "XL_Trắng": 5,
      "S_Xanh navy": 12,
      "M_Xanh navy": 15,
      "L_Xanh navy": 8,
      "XL_Xanh navy": 0, // Hết hàng SKU này để test out-of-stock badge
    },
    "soldCount": 145,
    "isActive": true,
    "rating": 4.9,
    "reviews": [
      {
        "userId": "usr_sample_01",
        "userName": "Trần Tuấn Anh",
        "rating": 5,
        "comment": "Áo mặc cực kỳ tôn dáng, vải mát không nhăn.",
        "createdAt": "2026-10-15T10:30:00Z",
        "orderId": "ord_mock_101",
        "variantInfo": "Phân loại: Size M, Màu Đen",
        "isVerifiedPurchase": true,
      },
      {
        "userId": "usr_sample_02",
        "userName": "Lê Hoàng Nam",
        "rating": 5,
        "comment": "Giao hàng nhanh, đóng gói hộp chỉn chu lắm nha shop.",
        "createdAt": "2026-10-16T14:20:00Z",
        "orderId": "ord_mock_102",
        "variantInfo": "Phân loại: Size L, Màu Trắng",
        "isVerifiedPurchase": true,
      }
    ]
  },

  // 2. Áo Thun Basic Compact
  {
    "id": "prod_002",
    "name": "Áo Thun Cổ Tròn Basic 100% Cotton",
    "categoryId": "cat_aothun",
    "price": 189000,
    "originalPrice": 220000,
    "description": "Sợi bông tự nhiên mềm mịn, thoáng khí, thấm hút mồ hôi tối ưu. Form suông năng động phù hợp cả đi học và dạo phố.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=800",
      "https://images.unsplash.com/photo-1583743814966-8936f5b7be1a?w=800",
    ],
    "sizes": ["S", "M", "L", "XL"],
    "colors": ["Trắng", "Đen", "Xám"],
    "stock": 176,
    "variantStock": {
      "S_Trắng": 20,
      "M_Trắng": 25,
      "L_Trắng": 15,
      "XL_Trắng": 10,
      "S_Đen": 18,
      "M_Đen": 22,
      "L_Đen": 14,
      "XL_Đen": 8,
      "S_Xám": 12,
      "M_Xám": 16,
      "L_Xám": 10,
      "XL_Xám": 6,
    },
    "soldCount": 320,
    "isActive": true,
    "rating": 4.8,
    "reviews": [
      {
        "userId": "usr_sample_03",
        "userName": "Nguyễn Minh Khang",
        "rating": 5,
        "comment": "Áo basic dễ phối đồ, giặt xong không bị co rút.",
        "createdAt": "2026-10-17T09:00:00Z",
        "orderId": "ord_mock_103",
        "variantInfo": "Phân loại: Size L, Màu Trắng",
        "isVerifiedPurchase": true,
      }
    ]
  },

  // 3. Áo Khoác Bomber Kháng Nước
  {
    "id": "prod_003",
    "name": "Áo Khoác Bomber Trượt Nước 2 Lớp",
    "categoryId": "cat_aokhoac",
    "price": 450000,
    "originalPrice": 550000,
    "description": "Vải dù cao cấp công nghệ trượt nước, cản gió giữ ấm cực tốt. Có 2 túi ngoài khóa zip và túi bảo mật bên trong ngực áo.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1548883354-7622d03aca27?w=800",
      "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=800",
    ],
    "sizes": ["M", "L", "XL"],
    "colors": ["Đen", "Xanh rêu"],
    "stock": 65,
    "variantStock": {
      "M_Đen": 12,
      "L_Đen": 15,
      "XL_Đen": 8,
      "M_Xanh rêu": 10,
      "L_Xanh rêu": 14,
      "XL_Xanh rêu": 6,
    },
    "soldCount": 88,
    "isActive": true,
    "rating": 5.0,
    "reviews": [
      {
        "userId": "usr_sample_04",
        "userName": "Võ Quốc Cường",
        "rating": 5,
        "comment": "Khoác ấm và nhẹ, đi mưa nhỏ không bị ngấm nước rất tiện.",
        "createdAt": "2026-10-18T16:45:00Z",
        "orderId": "ord_mock_104",
        "variantInfo": "Phân loại: Size XL, Màu Đen",
        "isVerifiedPurchase": true,
      }
    ]
  },

  // 4. Áo Hoodie Nỉ Bông Unisex
  {
    "id": "prod_004",
    "name": "Áo Hoodie Form Rộng Nỉ Bông Dày Dặn",
    "categoryId": "cat_aokhoac",
    "price": 380000,
    "originalPrice": 450000,
    "description": "Lớp lót nỉ bông ấm áp, mũ trùm 2 lớp có dây rút kim loại cao cấp. Thiết kế trẻ trung, form oversize chuẩn Hàn Quốc.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=800",
    ],
    "sizes": ["M", "L", "XL"],
    "colors": ["Xám", "Be", "Đen"],
    "stock": 133,
    "variantStock": {
      "M_Xám": 15,
      "L_Xám": 20,
      "XL_Xám": 10,
      "M_Be": 12,
      "L_Be": 18,
      "XL_Be": 8,
      "M_Đen": 16,
      "L_Đen": 22,
      "XL_Đen": 12,
    },
    "soldCount": 112,
    "isActive": true,
    "rating": 4.7,
    "reviews": [
      {
        "userId": "usr_sample_05",
        "userName": "Đặng Thị Mai",
        "rating": 5,
        "comment": "Áo dày dặn, mặc đi Đà Lạt vừa ấm vừa có ảnh đẹp.",
        "createdAt": "2026-10-18T11:15:00Z",
        "orderId": "ord_mock_105",
        "variantInfo": "Phân loại: Size M, Màu Be",
        "isVerifiedPurchase": true,
      }
    ]
  },

  // 5. Quần Jean Slimfit
  {
    "id": "prod_005",
    "name": "Quần Jean Nam Slimfit Co Giãn Nhẹ",
    "categoryId": "cat_quanjean",
    "price": 399000,
    "originalPrice": 480000,
    "description": "Chất denim wash màu hiện đại, pha sợi thun co giãn thoải mái khi vận động cả ngày. Khóa kéo đồng YKK bền bỉ.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1542272604-780c96856592?w=800",
      "https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=800",
    ],
    "sizes": ["S", "M", "L", "XL"],
    "colors": ["Xanh đậm", "Xanh nhạt", "Đen"],
    "stock": 132,
    "variantStock": {
      "S_Xanh đậm": 10,
      "M_Xanh đậm": 15,
      "L_Xanh đậm": 12,
      "XL_Xanh đậm": 6,
      "S_Xanh nhạt": 8,
      "M_Xanh nhạt": 14,
      "L_Xanh nhạt": 10,
      "XL_Xanh nhạt": 5,
      "S_Đen": 12,
      "M_Đen": 18,
      "L_Đen": 15,
      "XL_Đen": 7,
    },
    "soldCount": 215,
    "isActive": true,
    "rating": 4.9,
    "reviews": [
      {
        "userId": "usr_sample_06",
        "userName": "Phạm Gia Bảo",
        "rating": 5,
        "comment": "Quần ôm vừa chân, co giãn đứng lên ngồi xuống rất dễ chịu.",
        "createdAt": "2026-10-19T08:30:00Z",
        "orderId": "ord_mock_106",
        "variantInfo": "Phân loại: Size L, Màu Xanh đậm",
        "isVerifiedPurchase": true,
      }
    ]
  },

  // 6. Quần Short Khaki
  {
    "id": "prod_006",
    "name": "Quần Short Kaki Lưng Chun Thoáng Mát",
    "categoryId": "cat_quanjean",
    "price": 220000,
    "originalPrice": 260000,
    "description": "Lưng thun kèm dây rút tiện lợi, vải kaki dệt mật độ cao chống xù lông. Chiều dài trên gối năng động.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1591195853828-11db59a44f6b?w=800",
    ],
    "sizes": ["S", "M", "L", "XL"],
    "colors": ["Be", "Xám", "Đen"],
    "stock": 157,
    "variantStock": {
      "S_Be": 15,
      "M_Be": 20,
      "L_Be": 12,
      "XL_Be": 8,
      "S_Xám": 10,
      "M_Xám": 16,
      "L_Xám": 10,
      "XL_Xám": 6,
      "S_Đen": 14,
      "M_Đen": 22,
      "L_Đen": 15,
      "XL_Đen": 9,
    },
    "soldCount": 96,
    "isActive": true,
    "rating": 4.8,
    "reviews": []
  },

  // 7. Mũ Lưỡi Trai Classic
  {
    "id": "prod_007",
    "name": "Nón Lưỡi Trai Cotton Thêu Logo Tinh Tế",
    "categoryId": "cat_phukien",
    "price": 120000,
    "originalPrice": 150000,
    "description": "Form mũ cứng cáp giữ dáng tốt, khóa kim loại phía sau dễ điều chỉnh kích cỡ vòng đầu.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1588850561407-ed78c282e89b?w=800",
    ],
    "sizes": ["FreeSize"],
    "colors": ["Đen", "Trắng", "Xanh navy"],
    "stock": 75,
    "variantStock": {
      "FreeSize_Đen": 30,
      "FreeSize_Trắng": 25,
      "FreeSize_Xanh navy": 20,
    },
    "soldCount": 240,
    "isActive": true,
    "rating": 5.0,
    "reviews": []
  },

  // 8. Thắt Lưng Da Thật
  {
    "id": "prod_008",
    "name": "Thắt Lưng Da Bò Khóa Tự Động Cao Cấp",
    "categoryId": "cat_phukien",
    "price": 270000,
    "originalPrice": 320000,
    "description": "Da bò nguyên tấm 2 lớp, mặt khóa hợp kim không rỉ mạ titan sang trọng.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1624222247344-550fb60583dc?w=800",
    ],
    "sizes": ["FreeSize"],
    "colors": ["Đen", "Nâu"],
    "stock": 63,
    "variantStock": {
      "FreeSize_Đen": 35,
      "FreeSize_Nâu": 28,
    },
    "soldCount": 168,
    "isActive": true,
    "rating": 4.9,
    "reviews": []
  }
];

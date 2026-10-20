// Dữ liệu mẫu (Seed Data) cho cửa hàng thời trang Fashion Store
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
    "description": "Chất liệu 95% Cotton chải kỹ, 5% Spandex co giãn 4 chiều. Bo cổ dệt tinh tế, chống bai dão khi giặt máy.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1586363104862-3a5e2ab60d99?w=800",
      "https://images.unsplash.com/photo-1625910513413-56272517036a?w=800",
    ],
    "sizes": ["S", "M", "L", "XL"],
    "colors": ["Đen", "Trắng", "Xanh navy"],
    "rating": 4.9,
    "reviews": [
      {
        "userName": "Trần Tuấn Anh",
        "rating": 5,
        "comment": "Áo mặc cực kỳ tôn dáng, vải mát không nhăn.",
        "createdAt": "2026-10-15T10:30:00Z"
      },
      {
        "userName": "Lê Hoàng Nam",
        "rating": 5,
        "comment": "Giao hàng nhanh, đóng gói hộp chỉn chu lắm nha shop.",
        "createdAt": "2026-10-16T14:20:00Z"
      }
    ]
  },

  // 2. Áo Thun Basic Compact
  {
    "id": "prod_002",
    "name": "Áo Thun Cổ Tròn Basic 100% Cotton",
    "categoryId": "cat_aothun",
    "price": 189000,
    "description": "Sợi bông tự nhiên mềm mịn, thoáng khí, thấm hút mồ hôi tối ưu. Form suông năng động phù hợp cả đi học và dạo phố.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=800",
      "https://images.unsplash.com/photo-1583743814966-8936f5b7be1a?w=800",
    ],
    "sizes": ["S", "M", "L", "XL"],
    "colors": ["Trắng", "Đen", "Xám"],
    "rating": 4.8,
    "reviews": [
      {
        "userName": "Nguyễn Minh Khang",
        "rating": 5,
        "comment": "Áo basic dễ phối đồ, giặt xong không bị co rút.",
        "createdAt": "2026-10-17T09:00:00Z"
      }
    ]
  },

  // 3. Áo Khoác Bomber Kháng Nước
  {
    "id": "prod_003",
    "name": "Áo Khoác Bomber Trượt Nước 2 Lớp",
    "categoryId": "cat_aokhoac",
    "price": 450000,
    "description": "Vải dù cao cấp công nghệ trượt nước, cản gió giữ ấm cực tốt. Có 2 túi ngoài khóa zip và túi bảo mật bên trong ngực áo.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1548883354-7622d03aca27?w=800",
      "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=800",
    ],
    "sizes": ["M", "L", "XL"],
    "colors": ["Đen", "Xanh rêu"],
    "rating": 5.0,
    "reviews": [
      {
        "userName": "Võ Quốc Cường",
        "rating": 5,
        "comment": "Khoác ấm và nhẹ, đi mưa nhỏ không bị ngấm nước rất tiện.",
        "createdAt": "2026-10-18T16:45:00Z"
      }
    ]
  },

  // 4. Áo Hoodie Nỉ Bông Unisex
  {
    "id": "prod_004",
    "name": "Áo Hoodie Form Rộng Nỉ Bông Dày Dặn",
    "categoryId": "cat_aokhoac",
    "price": 380000,
    "description": "Lớp lót nỉ bông ấm áp, mũ trùm 2 lớp có dây rút kim loại cao cấp. Thiết kế trẻ trung, form oversize chuẩn Hàn Quốc.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=800",
    ],
    "sizes": ["M", "L", "XL"],
    "colors": ["Xám", "Be", "Đen"],
    "rating": 4.7,
    "reviews": [
      {
        "userName": "Đặng Thị Mai",
        "rating": 5,
        "comment": "Áo dày dặn, mặc đi Đà Lạt vừa ấm vừa có ảnh đẹp.",
        "createdAt": "2026-10-18T11:15:00Z"
      }
    ]
  },

  // 5. Quần Jean Slimfit
  {
    "id": "prod_005",
    "name": "Quần Jean Nam Slimfit Co Giãn Nhẹ",
    "categoryId": "cat_quanjean",
    "price": 399000,
    "description": "Chất denim wash màu hiện đại, pha sợi thun co giãn thoải mái khi vận động cả ngày. Khóa kéo đồng YKK bền bỉ.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1542272604-780c96856592?w=800",
      "https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=800",
    ],
    "sizes": ["S", "M", "L", "XL"],
    "colors": ["Xanh đậm", "Xanh nhạt", "Đen"],
    "rating": 4.9,
    "reviews": [
      {
        "userName": "Phạm Gia Bảo",
        "rating": 5,
        "comment": "Quần ôm vừa chân, co giãn đứng lên ngồi xuống rất dễ chịu.",
        "createdAt": "2026-10-19T08:30:00Z"
      }
    ]
  },

  // 6. Quần Short Khaki
  {
    "id": "prod_006",
    "name": "Quần Short Kaki Lưng Chun Thoáng Mát",
    "categoryId": "cat_quanjean",
    "price": 220000,
    "description": "Lưng thun kèm dây rút tiện lợi, vải kaki dệt mật độ cao chống xù lông. Chiều dài trên gối năng động.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1591195853828-11db59a44f6b?w=800",
    ],
    "sizes": ["S", "M", "L", "XL"],
    "colors": ["Be", "Xám", "Đen"],
    "rating": 4.8,
    "reviews": []
  },

  // 7. Mũ Lưỡi Trai Classic
  {
    "id": "prod_007",
    "name": "Nón Lưỡi Trai Cotton Thêu Logo Tinh Tế",
    "categoryId": "cat_phukien",
    "price": 120000,
    "description": "Form mũ cứng cáp giữ dáng tốt, khóa kim loại phía sau dễ điều chỉnh kích cỡ vòng đầu.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1588850561407-ed78c282e89b?w=800",
    ],
    "sizes": ["FreeSize"],
    "colors": ["Đen", "Trắng", "Xanh navy"],
    "rating": 5.0,
    "reviews": []
  },

  // 8. Thắt Lưng Da Thật
  {
    "id": "prod_008",
    "name": "Thắt Lưng Da Bò Khóa Tự Động Cao Cấp",
    "categoryId": "cat_phukien",
    "price": 270000,
    "description": "Da bò nguyên tấm 2 lớp, mặt khóa hợp kim không rỉ mạ titan sang trọng.",
    "imageUrls": [
      "https://images.unsplash.com/photo-1624222247344-550fb60583dc?w=800",
    ],
    "sizes": ["FreeSize"],
    "colors": ["Đen", "Nâu"],
    "rating": 4.9,
    "reviews": []
  }
];

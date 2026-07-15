import { View, Text, FlatList, Image, StyleSheet, ActivityIndicator } from 'react-native';
import { useEffect, useState } from 'react';
import { collection, getDocs } from 'firebase/firestore';
import { db } from '../../firebaseConfig';

// 🔥 صور التصنيفات
const categoryImages = {
  restaurant: require('../../assets/images/categories/restaurant.jpg'),
  pharmacy: require('../../assets/images/categories/pharmacy.jpg'),
  bakery: require('../../assets/images/categories/bakery.jpg'),
  supermarket: require('../../assets/images/categories/supermarket.jpg'),
};

// 🔥 صور المطاعم
const images = {
  burger: require('../../assets/images/restaurants/burger.jpg'),
  pizza: require('../../assets/images/restaurants/pizza.jpg'),
  coffee: require('../../assets/images/restaurants/coffee.jpg'),
  fried_chicken: require('../../assets/images/restaurants/fried_chicken.jpg'),
  shawarma: require('../../assets/images/restaurants/shawarma.jpg'),
  rice: require('../../assets/images/restaurants/rice.jpg'),
};

export default function HomeScreen() {
  const [data, setData] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchAll = async () => {
      try {
        // 🔹 جلب المطاعم
        const itemsSnap = await getDocs(collection(db, 'items'));
        const itemsList = itemsSnap.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
        }));
        setData(itemsList);

        // 🔹 جلب التصنيفات
        const catSnap = await getDocs(collection(db, 'categories'));
        const catList = catSnap.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
        }));
        setCategories(catList);

      } catch (e) {
        console.log('🔥 Firebase error:', e);
      } finally {
        setLoading(false);
      }
    };

    fetchAll();
  }, []);

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#fff" />
      </View>
    );
  }

  return (
    <View style={styles.container}>

      {/* 🔥 التصنيفات */}
      <FlatList
        data={categories}
        horizontal
        showsHorizontalScrollIndicator={false}
        keyExtractor={(item) => item.id}
        style={{ marginBottom: 10 }}
        renderItem={({ item }) => (
          <View style={styles.categoryCard}>
            <Image
              source={categoryImages[item.image as keyof typeof categoryImages] || categoryImages.restaurant}
              style={styles.categoryImage}
            />
            <Text style={styles.categoryTitle}>{item.title}</Text>
          </View>
        )}
      />

      {/* 🔥 المطاعم */}
      <FlatList
        data={data}
        numColumns={2}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <Image
              source={images[item.image as keyof typeof images] || images.burger}
              style={styles.image}
            />

            <Text style={styles.title}>{item.title}</Text>

            <Text style={styles.subtitle}>
              ⭐ 4.5 ⏱ 30 دقيقة
            </Text>
          </View>
        )}
      />

    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
    padding: 10,
  },

  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#000',
  },

  // 🔹 التصنيفات
  categoryCard: {
    marginRight: 12,
    alignItems: 'center',
  },

  categoryImage: {
    width: 70,
    height: 70,
    borderRadius: 10,
  },

  categoryTitle: {
    color: '#fff',
    marginTop: 5,
    fontSize: 12,
  },

  // 🔹 الكروت
  card: {
    flex: 1,
    backgroundColor: '#1c1c1c',
    margin: 8,
    borderRadius: 15,
    overflow: 'hidden',
  },

  image: {
    width: '100%',
    height: 140,
  },

  title: {
    color: '#fff',
    fontSize: 16,
    padding: 8,
  },

  subtitle: {
    color: '#aaa',
    fontSize: 12,
    paddingHorizontal: 8,
    paddingBottom: 8,
  },
});
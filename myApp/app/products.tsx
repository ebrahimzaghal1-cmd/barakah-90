import { useLocalSearchParams, useRouter } from 'expo-router';
import { collection, query, where, getDocs } from 'firebase/firestore';
import { db } from '../firebaseConfig';
import { useEffect, useState } from 'react';
import { View, Text, FlatList, Image } from 'react-native';

export default function Products() {
  const router = useRouter();
  const params = useLocalSearchParams();
  const category =
    typeof params.category === 'string'
      ? params.category.trim()
      : Array.isArray(params.category)
      ? params.category[0].trim()
      : '';
  const [items, setItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!category || category.length === 0) return;

    const fetchItems = async () => {
      try {
        console.log('CATEGORY FROM PARAM:', category);

        const categoryMap: any = {
          'مخابز': 'مخبوزات',
          'مطاعم': 'مطاعم',
          'قهوة': 'قهوة',
          'دجاج': 'دجاج',
          'لحوم': 'لحوم',
          'خضار وفواكه': 'خضار وفواكه',
          'أسماك': 'أسماك',
          'صيدلية': 'صيدلية',
          'سوبرماركت': 'سوبرماركت',
        };

        const fixedCategory = categoryMap[category] || category;

       const q = query(
         collection(db, 'items'),
         where('category', '==', fixedCategory)
       );

        const querySnapshot = await getDocs(q);

        const data = querySnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
        }));

        console.log('FILTER USED:', fixedCategory);
        console.log('DATA:', data);

        setItems(data);
      } catch (error) {
        console.log('ERROR:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchItems();
  }, [category]);

  return (
    <View style={{ flex: 1, backgroundColor: 'black', padding: 10 }}>
      <Text
        onPress={() => router.replace('/')}
        style={{ color: 'white', fontSize: 18, marginBottom: 10 }}
      >
        ← رجوع
      </Text>
      <Text style={{ color: 'white', fontSize: 22, marginBottom: 10, textAlign: 'center' }}>
        منتجات {category}
      </Text>

      {loading ? (
        <Text style={{ color: 'white' }}>جاري التحميل...</Text>
      ) : items.length === 0 ? (
        <Text style={{ color: 'gray' }}>لا يوجد منتجات</Text>
      ) : (
        <FlatList
          data={items}
          keyExtractor={(item) => item.id}
          numColumns={2}
          columnWrapperStyle={{ justifyContent: 'space-between' }}
          renderItem={({ item }) => {
            const validImage =
              typeof item.image === 'string' && item.image.startsWith('http')
                ? item.image
                : 'https://via.placeholder.com/150';

            return (
              <View
                style={{
                  flex: items.length === 1 ? 1 : 1,
                  margin: 8,
                  alignItems: 'center',
                  width: items.length === 1 ? '100%' : '48%',
                }}
              >
                <Image
                  source={{ uri: validImage }}
                  style={{
                    height: 180,
                    width: items.length === 1 ? '100%' : '100%',
                    borderRadius: 15,
                  }}
                />
                <Text style={{ color: 'white', marginTop: 5 }}>
                  {item.title}
                </Text>
              </View>
            );
          }}
        />
      )}
    </View>
  );
}

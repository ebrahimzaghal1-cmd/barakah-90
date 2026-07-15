import { View, Text, Image, FlatList, StyleSheet, Pressable } from 'react-native';
import { useRouter } from 'expo-router';
import { collection, getDocs } from 'firebase/firestore';
import { useEffect, useState } from 'react';
import { db } from '../../firebase/config';

export default function ExploreScreen() {
  const [categories, setCategories] = useState<any[]>([]);
  const router = useRouter();

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const snapshot = await getDocs(collection(db, 'categories'));

        const data = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
        }));

        setCategories(data);
      } catch (error) {
        console.log('ERROR:', error);
      }
    };

    fetchCategories();
  }, []);

  return (
    <View style={styles.container}>
      <FlatList
        data={categories}
        numColumns={2}
        keyExtractor={(item, index) => index.toString()}
        columnWrapperStyle={{ justifyContent: 'space-between' }}
        contentContainerStyle={{ padding: 10 }}
        renderItem={({ item }: any) => (
          <Pressable
            onPress={() => {
              router.push(`/products?category=${item.title}`);
            }}
            style={styles.card}
          >
            <Image
              source={
                item.image && item.image.startsWith('http')
                  ? { uri: item.image }
                  : require('../../assets/images/categories/bakery.jpg')
              }
              style={styles.image}
            />

            <View style={styles.overlay}>
              <Text style={styles.title}>{item.title}</Text>
            </View>
          </Pressable>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  card: {
    width: '48%',
    marginBottom: 15,
    borderRadius: 15,
    overflow: 'hidden',
  },
  image: {
    width: '100%',
    height: 170,
  },
  overlay: {
    position: 'absolute',
    bottom: 0,
    width: '100%',
    padding: 10,
  },
  title: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});
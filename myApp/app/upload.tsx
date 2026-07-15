import { View, Button, Image } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useState } from 'react';

import { storage, db } from '../firebaseConfig';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { addDoc, collection } from 'firebase/firestore';

export default function UploadScreen() {
  const [image, setImage] = useState<string | null>(null);

  const pickImage = async () => {
    let result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 1,
    });

    if (!result.canceled) {
      setImage(result.assets[0].uri);
    }
  };

  const uploadImage = async () => {
    if (!image) return;

    const response = await fetch(image);
    const blob = await response.blob();

    const filename = `images/${Date.now()}.jpg`;
    const storageRef = ref(storage, filename);

    await uploadBytes(storageRef, blob);

    const downloadURL = await getDownloadURL(storageRef);

    // 🔥 نحفظ في Firestore
    await addDoc(collection(db, 'items'), {
      title: 'منتج جديد',
      category: 'دجاج',
      image: downloadURL,
    });

    alert('تم رفع الصورة بنجاح 🔥');
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <Button title="اختيار صورة" onPress={pickImage} />
      <Button title="رفع الصورة" onPress={uploadImage} />

      {image && (
        <Image source={{ uri: image }} style={{ width: 200, height: 200, marginTop: 20 }} />
      )}
    </View>
  );
}
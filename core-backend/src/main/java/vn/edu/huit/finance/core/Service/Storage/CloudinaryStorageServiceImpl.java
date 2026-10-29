package vn.edu.huit.finance.core.Service.Storage;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

@Service
public class CloudinaryStorageServiceImpl implements FileStorageService {

    // secure_url là link https; checkout chỉ nhận link ảnh https (TransactionRequestDto.imageUrl).
    private static final String SECURE_URL_KEY = "secure_url";
    private static final String URL_KEY = "url";

    @Autowired
    private Cloudinary cloudinary;

    @Override
    public String uploadFile(MultipartFile file) throws IOException {
        Map uploadResult = cloudinary.uploader().upload(file.getBytes(), ObjectUtils.emptyMap());

        Object link = uploadResult.get(SECURE_URL_KEY);
        if (link == null) {
            link = uploadResult.get(URL_KEY);
        }
        return link == null ? null : link.toString();
    }
}

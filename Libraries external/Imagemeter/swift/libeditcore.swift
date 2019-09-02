import Foundation

public class Imagemeter {

    public class func computeImagemeter() -> Int32 {
        return computeValue()
    }

    public class func computeFaculty(n : Int32) -> Int32 {
        return im_computeFaculty(n)
    }
    
    public class func stringLength(str : String) -> Int32 {
        return im_stringLength(str);
    }

    public class func toUpper(str : String) -> String {
        let upperCStr = UnsafeMutablePointer<Int8>(im_toUpper(str))!
        let upper = String(cString: upperCStr)
        free(upperCStr)
        return upper
    }
    
    public class func hash(data : [UInt8], dataSize : Int32) -> UInt8 {
        return im_hash(UnsafePointer(data), dataSize);
    }
    
    public class func encodeCodedJson(json : String) -> Data {
        let codedFile = im_encodeCodedJson(UnsafePointer(json))
        
        let cPtr = UnsafePointer<UInt8>(codedFile.mem)!
        
//        let buffer = UnsafeBufferPointer<UInt8>(start: cPtr, count: Int(codedFile.size))
//        let coded = Array(buffer)
//        return coded
        
        let outputData = Data(bytes: cPtr, count: Int(codedFile.size))
        return outputData
    }
    
    public class func decodeCodedJson(input : Data) -> String {
        let inputData = NSData(data: input)
        let ptrToInput = inputData.bytes.assumingMemoryBound(to: UInt8.self)
        let cStr = UnsafeMutablePointer<Int8>(im_decodeCodedJson(ptrToInput, Int32(input.count)))!
        let json = String(cString : cStr)
        free(cStr)
        return json
    }
}

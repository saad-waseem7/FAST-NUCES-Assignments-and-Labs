#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>
#include <cstdlib>
#include <cstring>

using namespace std;

#define MAX_FILES 100
#define MAX_THREADS 5

struct SharedMemory
{
    string fileNames[MAX_FILES];
    bool fileProcessed[MAX_FILES];
    int fileCount;

    bool wordFound;
    string resultFile;
    int resultLine;

    sem_t mutex;
};

SharedMemory shared;
string searchWord;

void *searchFile(void *arg)
{
    while (true)
    {
        if (shared.wordFound)
            pthread_exit(nullptr);

        int fileIndex = -1;

        // Critical section to pick an unprocessed file
        sem_wait(&shared.mutex);
        for (int i = 0; i < shared.fileCount; ++i)
        {
            if (!shared.fileProcessed[i])
            {
                shared.fileProcessed[i] = true;
                fileIndex = i;
                break;
            }
        }
        sem_post(&shared.mutex);

        if (fileIndex == -1)
            pthread_exit(nullptr); // No files left

        string filePath = shared.fileNames[fileIndex];
        ifstream file(filePath);
        if (!file.is_open())
            continue;

        string line;
        int lineNum = 0;
        while (getline(file, line))
        {
            if (shared.wordFound)
            {
                file.close();
                pthread_exit(nullptr);
            }

            lineNum++;
            if (line.find(searchWord) != string::npos)
            {
                sem_wait(&shared.mutex);
                if (!shared.wordFound)
                {
                    shared.wordFound = true;
                    shared.resultFile = filePath;
                    shared.resultLine = lineNum;
                }
                sem_post(&shared.mutex);
                file.close();
                pthread_exit(nullptr);
            }
        }

        file.close();
    }
    return nullptr;
}
int main(int argc, char *argv[])
{
    if (argc != 3)
    {
        cerr << "Usage: " << argv[0] << " <folder_path> <search_word>\n";
        return 1;
    }

    string folderPath = argv[1];
    searchWord = argv[2];

    // Initialize shared memory
    shared.fileCount = 0;
    shared.wordFound = false;
    sem_init(&shared.mutex, 0, 1);

    // Get .txt files using system call
    string command = "ls " + folderPath + "/*.txt > temp.txt";
    system(command.c_str());

    ifstream temp("temp.txt");
    string fileName;
    while (getline(temp, fileName) && shared.fileCount < MAX_FILES)
    {
        shared.fileNames[shared.fileCount] = fileName;
        shared.fileProcessed[shared.fileCount] = false;
        shared.fileCount++;
    }
    temp.close();
    system("rm temp.txt");

    // Create thread pool
    pthread_t threads[MAX_THREADS];
    for (int i = 0; i < MAX_THREADS; ++i)
    {
        pthread_create(&threads[i], nullptr, searchFile, nullptr);
    }

    // Wait for threads to finish
    for (int i = 0; i < MAX_THREADS; ++i)
    {
        pthread_join(threads[i], nullptr);
    }

    // Final result
    if (shared.wordFound)
    {
        cout << "Word found in file: " << shared.resultFile
             << " at line: " << shared.resultLine << endl;
    }
    else
    {
        cout << "Word not found.\n";
    }

    sem_destroy(&shared.mutex);
    return 0;
}
